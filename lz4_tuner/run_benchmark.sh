#!/bin/bash

accelerator=(1 2 3 5 8 13 21 34)
workload=(0 10 20 30 40 50 60 70 80 90 100)
#accelerator=(1 2 3)
#workload=(50)
operations=1000000

experiment_stats=$(date +"%T").out
touch $experiment_stats

for a in "${accelerator[@]}"; do
    echo -n "Accelerator:$a @"
    date +"%T"
    for w in "${workload[@]}"; do
        ./build/tuner -w $w.app -n $operations -a $a >> $experiment_stats
    done
done
