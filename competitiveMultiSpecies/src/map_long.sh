#!/bin/bash

set -ex
source "$(pwd)/config"
source "$(conda info --base)/etc/profile.d/conda.sh"

IndS="$1"
if [[ -z "$IndS" ]]; then
  echo "Errore: specificare un ID campione come primo argomento."
  exit 1
fi

# Verifica se il campione è già stato processato
if grep -qw "$IndS" "${cpsDir}/cps.txt"; then
  echo "Campione $IndS già presente in cps.txt, salto."
  exit 0
fi

# File di reads long
inputFile=$(find "${fastqDir}" -name "${IndS}*.fastq.gz" | head -n1)
if [[ ! -f "$inputFile" ]]; then
  echo "Errore: nessun file trovato per $IndS in ${fastqDir}"
  exit 1
fi

conda activate minimap2
for filepath in "$multiFastaDir"/*.fa; do
	filename=$(basename "$filepath")
        nameID="${filename%.fa}"
	mkdir -p "${mapDir}/${nameID}"
	mapDirName="${mapDir}/${nameID}"

        # Assembly di riferimento
        IndR=$(ls "${repDir}"/"${nameID}"/*.fa | head -n1)
        refID=$(basename "$IndR" | cut -d "." -f1)
        
        # Mapping long reads con preset "map-ont"
        minimap2 -t "$nThreads" -a -x map-ont "$IndR" "$inputFile" | samtools view -q 60 -@ "$add" -Obam,level=1 -o "${mapDirName}/${IndS}.${nameID}.bam"
        
        # Samtools workflow
        samtools sort -l 1 -@ "$nThreads" "${mapDirName}/${IndS}.${nameID}.bam" -T "${tmpDir}/${IndS}.${nameID}.tmp" -o "${mapDirName}/${IndS}.${nameID}.srt.bam"
        rm -f "${mapDirName}/${IndS}.${nameID}.bam"
        
        samtools markdup -@ "$add" -Obam,level=1 "${mapDirName}/${IndS}.${nameID}.srt.bam" "${mapDirName}/${IndS}.${nameID}.${refID}.temp.bam"
        rm -f "${mapDirName}/${IndS}.${nameID}.srt.bam"
        
	#secondary, duplicates and supplementary
	samtools view -@ "$add" -F 3328 -Obam,level=1 "${mapDirName}/${IndS}.${nameID}.${refID}.temp.bam" -o "${mapDirName}/${IndS}.${nameID}.${refID}.bam"
	rm -f "${mapDirName}/${IndS}.${nameID}.${refID}.temp.bam"

	samtools index "${mapDirName}/${IndS}.${nameID}.${refID}.bam"
done

conda deactivate
# Appendi il campione a cps.txt
echo "$IndS" >> "${cpsDir}/cps.txt"
