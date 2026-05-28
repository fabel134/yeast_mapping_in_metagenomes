#!/bin/bash

set -x
source "$(pwd)/config"
source "$(conda info --base)/etc/profile.d/conda.sh"

conda activate base

for filepath in "$lengthChrsDir"/*.chrs.len; do
    filename=$(basename "$filepath")
    nameID="${filename%.chrs.len}"
    /usr/bin/time -v python "${srcDir}/bed.py" "${lengthChrsDir}/${nameID}.chrs.len" "${bedDir}" "${nameID}" "${bin_step}"
done

conda deactivate
