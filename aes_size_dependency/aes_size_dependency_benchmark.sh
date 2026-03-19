#!/bin/bash
OUTPUT="aes_size_dependency_results.csv"
echo "Bytes,PPS,Throughput_KB" > $OUTPUT

for BYTES in $(seq 1024 1024 8192); do
    timestamp=$(date +"%T")
    echo "$timestamp  Testing $BYTES bytes..."
    # Extract the last column (throughput in KB/s) from the 'evp' line
    openssl speed -evp aes-128-cbc -bytes $BYTES -seconds 10 &> crypto.tmp
    PPS=$(cat crypto.tmp | grep 'Doing' | awk -F ': | AES' '{print $3}')
    THROUGHPUT=$(cat crypto.tmp | tail -1 | awk -F '     |k' '{print $2}')
    echo "$BYTES,$PPS,$THROUGHPUT" >> $OUTPUT
done
