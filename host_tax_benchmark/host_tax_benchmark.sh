#!/bin/bash

# --- 1. Cleanup Routine ---
kill_app() {
    APP=$1
    kill -9 $(ps -ux | grep $APP | awk -F ' ' '{ print $2 }') 2> /dev/null 
}
cleanup() {
    echo -e "\n[!] Cleaning up background processes..."
    [[ -n "$LATENCY_PID" ]] && kill $LATENCY_PID 2>/dev/null
    # Global pkill ensures no detached setsid processes survive
    kill_app lz4
    kill_app openssl
    pkill -P $$ 2>/dev/null
    exit 1
}

trap cleanup SIGINT SIGTERM

# --- 2. Hardware and Latency Setup ---
TOTAL_CORES=$(nproc)
MAX_TAX_CORES=$((TOTAL_CORES - 2))
START_TAX_CORE=1
APP_CORE=9
CORE_COUNTS=(2 4 6 8)
SAMPLES=5


# Start Latency Pin to stabilize the 0.26 IPC
if [ -f "zero_dma_latency.py" ]; then
    echo "[+] Pinning CPU DMA Latency to 0..."
    python3 zero_dma_latency.py & 
    LATENCY_PID=$!
    sleep 2 
fi

# --- 3. Configuration ---
MATRIX_SIZE=16384
OUTPUT_FILE="host_tax_results.csv"
echo "Mode,Cores,Sample,CompletionTime,LLC_Misses,IPC" > $OUTPUT_FILE

run_sample() {
    local mode=$1
    local cores=$2
    local sample_num=$3

    timestamp=$(date +"%T")
    echo "$timestamp Running $mode with $cores cores (Sample $sample_num)..."
    
    local end_core=$((START_TAX_CORE + cores - 1))
    local core_range="$START_TAX_CORE-$end_core"

    # --- 4. Start Background Tax (Taskset Restored) ---
    case $mode in
        "baseline")
            ;;
        "encrypt")
            taskset -c $core_range openssl speed -evp aes-128-cbc -multi $cores -bytes 8192 -seconds 1000 > ssl_out.tmp 2>&1 &
            ;;
        "compress")
            for i in $(seq $START_TAX_CORE $end_core); do
                taskset -c $i /bin/bash -c "while true; do head -c 8192 /dev/zero | lz4 -z -; done > /dev/null 2>&1" &
            done;
            ;;
        "full_tax")
            half=$((cores / 2))
            [[ $half -lt 1 ]] && half=1
            local enc_range="$START_TAX_CORE-$((START_TAX_CORE + half - 1))"
            local comp_start=$((START_TAX_CORE + half))
            
            taskset -c $enc_range openssl speed -evp aes-128-cbc -multi $half -bytes 8192 -seconds 1000 > ssl_out.tmp 2>&1 &
            for i in $(seq $comp_start $end_core); do
                taskset -c $i /bin/bash -c "while true; do head -c 8192 /dev/zero | lz4 -z -; done > /dev/null 2>&1" &
            done;
            ;;
    esac

    sleep 2

    # --- 5. Run Science App ---
    sudo taskset -c $APP_CORE perf stat -e cycles,instructions,LLC-load-misses \
        ./science_proxy $MATRIX_SIZE $mode > proxy_out.tmp 2> perf_out.tmp

    # --- 6. Cleanup for this specific sample ---
    kill_app lz4
    kill_app openssl

    # --- 7. Metrics Extraction ---
    TIME=$(grep "Completion Time" proxy_out.tmp | awk '{print $3}' | sed 's/s//')
    LLC=$(grep "LLC-load-misses" perf_out.tmp | awk '{print $1}' | tr -d ',')
    IPC=$(grep "insn per cycle" perf_out.tmp | awk '{print $4}')

    echo "$mode,$cores,$sample_num,$TIME,$LLC,$IPC" >> $OUTPUT_FILE
}

# --- 8. Main Loop ---
for mode in "baseline" "encrypt" "compress" "full_tax"; do
    if [ "$mode" == "baseline" ]; then
        for i in $(seq 1 $SAMPLES); do run_sample "baseline" 0 $i; done
    else
        for c in "${CORE_COUNTS[@]}"; do
            if [ $c -le $MAX_TAX_CORES ]; then
                for i in $(seq 1 $SAMPLES); do run_sample $mode $c $i; done
            fi
            sleep 1
        done
    fi
    sleep 1
done

cleanup
