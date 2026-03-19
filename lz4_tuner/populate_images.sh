#!/bin/bash
for (( p=0; p<110; p+=10 )); do
    python dummy_image_generator.py $p.app $p
done

