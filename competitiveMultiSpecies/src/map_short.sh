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

# Verifica presenza file reverse (_2)
reverse=$(find "${fastqDir}" -name "${IndS}_2.fastq.gz")

conda activate bwa-mem2
for filepath in "$multiFastaDir"/*.fa; do
	filename=$(basename "$filepath")
        nameID="${filename%.fa}"
	mkdir -p "${mapDir}/${nameID}"
	mapDirName="${mapDir}/${nameID}"

        # Assembly di riferimento
        IndR=$(ls "${repDir}"/"${nameID}"/*.fa | head -n1)
        refID=$(basename "$IndR" | cut -d "." -f1)
        
        # Mapping con Minimap2
        if [[ -n "$reverse" ]]; then
	  bwa-mem2 mem -t "$nThreads" "$IndR" "${fastqDir}/${IndS}_1"*".fastq.gz" "${fastqDir}/${IndS}_2"*".fastq.gz" | samtools view -q 60 -@ "$add" -Obam,level=1 -o "${mapDirName}/${IndS}.${nameID}.bam"
        else
	  if [[ -n "${fastqDir}/${IndS}_1.fastq.gz" ]]; then
	     bwa-mem2 mem -t "$nThreads" "$IndR" "${fastqDir}/${IndS}_1.fastq.gz" | samtools view -q 60 -@ "$add" -Obam,level=1 -o "${mapDirName}/${IndS}.${nameID}.bam"
	  else
	     bwa-mem2 mem -t "$nThreads" "$IndR" "${fastqDir}/${IndS}.fastq.gz" | samtools view -q 60 -@ "$add" -Obam,level=1 -o "${mapDirName}/${IndS}.${nameID}.bam"
	  fi
        fi

        # Samtools workflow
	samtools fixmate -z all -@ "$add" -Obam,level=1 -m "${mapDirName}/${IndS}.${nameID}.bam" "${mapDirName}/${IndS}.${nameID}.fix.bam"
        rm -f "${mapDir}/${IndS}.${nameID}.bam"
 
        samtools sort -l 1 -@ "$nThreads" "${mapDirName}/${IndS}.${nameID}.fix.bam" -T "${tmpDir}/${IndS}.${nameID}.tmp" -o "${mapDirName}/${IndS}.${nameID}.srt.bam"
        rm -f "${mapDirName}/${IndS}.${nameID}.fix.bam"
        
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
