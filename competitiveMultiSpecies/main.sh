#!/bin/bash

set -e pipefail
source config

source "$(conda info --base)/etc/profile.d/conda.sh"


if [[ -d ${logsDir} ]]; then rm -rf ${logsDir}; fi
mkdir -p ${logsDir}
mkdir -p "${logsDir}/batches"

/usr/bin/time -v bash "${BaseDir}/initialize.sh" > "${logsDir}/initialize.log" 2> "${logsDir}/initialize.err"
/usr/bin/time -v bash "${srcDir}/add_fasta.sh" > "${logsDir}/add_fasta.log" 2> "${logsDir}/add_fasta.err"
/usr/bin/time -v bash "${srcDir}/indexing.sh" > "${logsDir}/indexing.log" 2> "${logsDir}/indexing.err"
/usr/bin/time -v bash "${srcDir}/length_chr.sh" > "${logsDir}/length_chr.log" 2> "${logsDir}/length_chr.err"
/usr/bin/time -v bash "${srcDir}/bed.sh" > "${logsDir}/bed.log" 2> "${logsDir}/bed.err"

conda activate base
/usr/bin/time -v python "${srcDir}/list_chr.py" "${multiFastaDir}" "${listChrsDir}" > "${logsDir}/list_chr.log" 2> "${logsDir}/list_chr.err"
conda deactivate

echo "Processing batch in parallel..."

process_fastq() {
  local ind=$1
  local srcDir=$2 
  local logsDir=$3
  local typeReads=$4 

  if [[ "$typeReads" == "long" ]]; then 
    /usr/bin/time -v bash "${srcDir}/map_long.sh" "${ind}" >> "${logsDir}/map_long.log" 2>> "${logsDir}/map_long.err" 
  elif [[ "$typeReads" == "short" ]]; then
    /usr/bin/time -v bash "${srcDir}/map_short.sh" "${ind}" >> "${logsDir}/map_short.log" 2>> "${logsDir}/map_short.err" 
  else
    echo "Errore: typeReads deve essere 'long' o 'short'"
    exit 1
  fi

  /usr/bin/time -v bash "${srcDir}/coverage.sh" "${ind}" >> "${logsDir}/coverage.log" 2>> "${logsDir}/coverage.err"
  /usr/bin/time -v bash "${srcDir}/plot.sh" "${ind}" >> "${logsDir}/plot.log" 2>> "${logsDir}/plot.err"
}

export -f process_fastq

split -l "$nBatch" -d -a 3 "${BaseDir}/file" "${logsDir}/batches/batch_"

for batch in "${logsDir}/batches"/batch_*; do
  echo "Processing batch ${batch}"

  cat "$batch" | parallel -j "$nBatch" process_fastq {} "${srcDir}" "${logsDir}" "${typeReads}"

  echo "Batch ${batch} completato."

  if [[ "${archiveYes}" == "yes" ]]; then
    echo "Compressione parallela dei file .bam + .bai da ${mapDir} → ${outDir}..."

    export mapDir outDir
    compress_bam() {
      local bamFile="$1"
      local baiFile="${bamFile%.bam}.bai"
      local sampleName
      sampleName="$(basename "${bamFile}" .bam)"
      local archiveName="${outDir}/${sampleName}.tar.gz"

      if [[ -f "$baiFile" ]]; then
        echo "Archivio: $archiveName"
        tar -cf - "$bamFile" "$baiFile" | pigz -9 -p 2 > "$archiveName"
        rm -f "$bamFile" "$baiFile"
      else
        echo "Manca il file .bai per $bamFile saltato"
      fi
    }
    export -f compress_bam

    find "$mapDir" -type f -name "*.bam" | parallel -j "$nBatch" compress_bam {}
  elif [[ "${archiveYes}" == "no" ]]; then
    echo "Archivio disattivato (archiveYes=no). I file .bam e .bai restano in ${mapDir}."
  elif [[ "${archiveYes}" == "delete" ]]; then
    echo "Cancellazione file .bam, .bai e .binned.cov per i campioni nel batch ${batch}..."

    while IFS= read -r ind; do
      # Elimina tutti i .bam e .bam.bai che iniziano con "$ind."
      find "$mapDir" -type f -name "${ind}.*.bam" -exec bash -c '
        for bam; do
          echo "Rimozione: $bam"
          rm -f "$bam"
          bai="${bam}.bai"
          if [[ -f "$bai" ]]; then
            echo "Rimozione: $bai"
            rm -f "$bai"
          fi
        done
      ' _ {} +

      ## Elimina il file .binned.cov corrispondente
      #covFile="${covDir}/${ind}.binned.cov"
      #if [[ -f "$covFile" ]]; then
      #  echo "Rimozione: $covFile"
      #  rm -f "$covFile"
      #fi
    done < "$batch"
  fi
done

echo "analysis terminated by $USER at $(date "+%D %r")" > "${logsDir}/main.log" 2> "${logsDir}/main.err"
