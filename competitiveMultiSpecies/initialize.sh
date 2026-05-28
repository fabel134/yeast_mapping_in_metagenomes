#!/bin/bash

set -ex
source config

# Controllo variabili richieste
: "${mapDir:?}"
: "${cpsDir:?}"
: "${repDir:?}"
: "${covDir:?}"
: "${tmpDir:?}"
: "${bedDir:?}"
: "${lengthChrsDir:?}"
: "${listChrsDir:?}"
: "${plotDir:?}"
: "${multiFastaDir:?}"
: "${FILE:?}"
: "${fastqDir:?}"
: "${typeReads:?}"

# Controllo valore valido per typeReads
if [[ "$typeReads" != "long" && "$typeReads" != "short" ]]; then
  echo "Errore: typeReads deve essere 'long' or 'short'"
  exit 1
fi

# Inizializza directory
[[ -d "${mapDir}" ]] && rm -rf "${mapDir}"
mkdir -p "${mapDir}"

[[ -d "${repDir}" ]] && rm -rf "${repDir}"
mkdir -p "${repDir}"

[[ -d "${cpsDir}" ]] && rm -rf "${cpsDir}"
mkdir -p "${cpsDir}"

[[ -d "${covDir}" ]] && rm -rf "${covDir}"
mkdir -p "${covDir}"

[[ -d "${tmpDir}" ]] && rm -rf "${tmpDir}"
mkdir -p "${tmpDir}"

if [[ -d ${bedDir} ]]; then rm -rf ${bedDir}; fi
mkdir ${bedDir}

if [[ -d ${lengthChrsDir} ]]; then rm -rf ${lengthChrsDir}; fi
mkdir ${lengthChrsDir}

if [[ -d ${listChrsDir} ]]; then rm -rf ${listChrsDir}; fi
mkdir ${listChrsDir}

if [[ -d ${plotDir} ]]; then rm -rf ${plotDir}; fi
mkdir ${plotDir}

if [[ -d ${multiFastaDir} ]]; then rm -rf ${multiFastaDir}; fi
mkdir ${multiFastaDir}


#copy multifasta file in multifasta folder
cp "$sacchDir"/multi_species.fa "$multiFastaDir"

# Controlla o crea il file FILE
if [[ -f "${FILE}" ]]; then
  echo "${FILE} exists."
  rm -rf "${FILE}"
  touch "${FILE}"
  echo "${FILE} created."
else
  touch "${FILE}"
  echo "${FILE} created."
fi

# Controlla o crea il file checkFile
if [[ -f "${checkFile}" ]]; then
  echo "${checkFile} exists"
else
  touch "${checkFile}"
  echo "${checkFile} created."
fi

names=$(find "${fastqDir}" -name '*.fastq.gz' \
  | rev | cut -d'/' -f1 | rev \
  | sed -E 's/_([12])\.fastq\.gz$//' \
  | sed -E 's/\.fastq\.gz$//' \
  | sort -u)

echo "${names}" > "${FILE}"

echo "Trovati i seguenti file nella directory ${fastqDir}:"
echo "${names}"
echo "Nomi salvati in ${FILE}"
echo "Inizializzazione completata"
