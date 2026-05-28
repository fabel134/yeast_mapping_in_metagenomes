#!/bin/bash

set -x
source "$(pwd)/config"
source "$(conda info --base)/etc/profile.d/conda.sh"

IndS="${1}"

conda activate samtools

for filepath in "$multiFastaDir"/*.fa; do
	filename=$(basename "$filepath")
        nameID="${filename%.fa}"
	mkdir -p "${covDir}/${nameID}"
	covDirName="${covDir}/${nameID}"

        # Assembly di riferimento
        IndR=$(ls "${repDir}"/"${nameID}"/*.fa | head -n1)
        refID=$(basename "$IndR" | cut -d "." -f1)

        cat $bedDir"/${nameID}.bed" | awk '{print $1":"$2"-"$3}' | xargs -P 10 -I {} samtools coverage -q30 -Q30 --ff UNMAP,SECONDARY,QCFAIL,DUP -r {} $mapDir/$nameID/$IndS.$nameID.$refID.bam | grep -v "#" | cut -f1-10 >> $covDirName/$IndS.$nameID.binned.cov
done

conda deactivate

