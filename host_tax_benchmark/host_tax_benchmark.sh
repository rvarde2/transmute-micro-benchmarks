#!/bin/bash

# 1. Hardware Detection
TOTAL_CORES=$(nproc)
MAX_TAX_CORES=$((TOTAL_CORES - 2))
START_TAX_CORE=1
# We reserve the LAST core for the Science App
#APP_CORE=$((TOTAL_CORES - 1))
# Adjust scaling steps based on available cores
#if [ $MAX_TAX_CORES -le 4 ]; then
#    CORE_COUNTS=(1 2)
#else
#    CORE_COUNTS=(1 2 4)
#fi

APP_CORE=9
CORE_COUNTS=(2 4 6 8)

echo "System Detected: $TOTAL_CORES cores."
echo "Science App pinned to Core $APP_CORE."

# Configuration
SAMPLES=5
MATRIX_SIZE=16384
OUTPUT_FILE="host_tax_results.csv"

echo "Mode,Cores,Sample,CompletionTime,LLC_Misses,IPC" > $OUTPUT_FILE

run_sample() {
    local mode=$1
    local cores=$2
    local sample_num=$3

    timestamp=$(date +"%T")
    echo "$timestamp $mode $sample_num"
    
    # Define the range: e.g., if cores=2 and start=1, range is 1-2
    local end_core=$((START_TAX_CORE + cores - 1))
    local core_range="$START_TAX_CORE-$end_core"

    # 2. Start Background Tax
    case $mode in
        "baseline")
            TAX_PID=""
            ;;
        "encrypt")
            setsid taskset -c $core_range openssl speed -evp aes-128-cbc \
                -multi $cores -bytes 8192 -seconds 1000 > ssl_out.tmp 2>&1 &
            TAX_PID=$!
            ;;
        "compress")
            setsid /bin/bash -c "for i in \$(seq $START_TAX_CORE $end_core); do \
                while true; do head -c 8192 /dev/zero | taskset -c \$i lz4 -z -; done > /dev/null 2>&1 & \
                done; wait" &
            TAX_PID=$!
            ;;
        "full_tax")
            half=$((cores / 2))
            [[ $half -lt 1 ]] && half=1
            local enc_range="$START_TAX_CORE-$((START_TAX_CORE + half - 1))"
            local comp_start=$((START_TAX_CORE + half))

            setsid /bin/bash -c "taskset -c $enc_range openssl speed -evp aes-128-cbc -multi $half -bytes 8192 -seconds 1000 > ssl_out.tmp 2>&1 & \
                for i in \$(seq $comp_start $end_core); do \
                while true; do head -c 8192 /dev/zero | taskset -c \$i lz4 -z -; done > /dev/null 2>&1 & \
                done; wait" &
            TAX_PID=$!
            ;;
    esac

    sleep 2

    # 3. Run Science App (Pinned to APP_CORE)
    sudo taskset -c $APP_CORE perf stat -e cycles,instructions,LLC-load-misses \
        ./science_proxy $MATRIX_SIZE $mode > proxy_out.tmp 2> perf_out.tmp

    # 4. Clean up
    if [ -n "$TAX_PID" ]; then
        pkill -P $TAX_PID 2>/dev/null
        kill $TAX_PID 2>/dev/null
        pkill -9 lz4 2>/dev/null
        pkill -9 openssl 2>/dev/null
    fi

    # 5. Extract Metrics
    TIME=$(grep "Completion Time" proxy_out.tmp | awk '{print $3}' | sed 's/s//')
    LLC=$(grep "LLC-load-misses" perf_out.tmp | awk '{print $1}' | tr -d ',')
    IPC=$(grep "insn per cycle" perf_out.tmp | awk '{print $4}')

    echo "$mode,$cores,$sample_num,$TIME,$LLC,$IPC" >> $OUTPUT_FILE
}

# --- Execution ---
for mode in "baseline" "encrypt" "compress" "full_tax"; do
    if [ "$mode" == "baseline" ]; then
        for i in $(seq 1 $SAMPLES); do run_sample "baseline" 0 $i; done
    else
        for c in "${CORE_COUNTS[@]}"; do
            if [ $c -le $MAX_TAX_CORES ]; then
                for i in $(seq 1 $SAMPLES); do run_sample $mode $c $i; done
            fi
        done
    fi
done
