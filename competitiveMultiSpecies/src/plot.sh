#!/bin/bash

set -x
source "$(pwd)/config"
source "$(conda info --base)/etc/profile.d/conda.sh"

IndS="${1}"

conda activate base
for filepath in "$multiFastaDir"/*.fa; do
	filename=$(basename "$filepath")
        nameID="${filename%.fa}"
	mkdir -p "${plotDir}/${nameID}"
	covDirName="${covDir}/${nameID}"
	plotDirName="${plotDir}/${nameID}"

        gawk -i inplace -v var="$IndS" -F'\t' 'BEGIN{OFS=FS}{print $0 OFS var}' "$covDirName/${IndS}.${nameID}.binned.cov"

        /usr/bin/time -v python "${srcDir}/comp_plot.py" "${BaseDir}" "${IndS}" "${nameID}" "${plotDirName}" "${listChrsDir}/${nameID}.chrs.list" > "${logsDir}/comp_plot.log" 2> "${logsDir}/comp_plot.err"
done
conda deactivate
