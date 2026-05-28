#!/bin/bash

set -ex
source "$(pwd)/config"
source "$(conda info --base)/etc/profile.d/conda.sh"

conda activate bwa-mem2

commonMultiFasta="$multiFastaDir"/multi_species.fa
filename=$(basename "$commonMultiFasta")
nameID="${filename%.fa}"
mkdir -p "${repDir}/${nameID}"
cp "$commonMultiFasta" "${repDir}/${nameID}"
samtools faidx "${repDir}/${nameID}/${nameID}.fa" 
bwa-mem2 index "${repDir}/${nameID}/${nameID}.fa"

conda deactivate
