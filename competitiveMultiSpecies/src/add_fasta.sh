#!/bin/bash

set -x
source "$(pwd)/config"
source "$(conda info --base)/etc/profile.d/conda.sh"

commonMultiFasta="$multiFastaDir/multi_species.fa"

strains_file="$sacchDir/strains.txt"

while read -r strain; do

    [[ -z "$strain" || "$strain" == \#* ]] && continue

    fasta_path="$genomesDir/$strain.fa"

    if [[ -s "$fasta_path" ]]; then
        cat "$fasta_path" >> "$commonMultiFasta"
    else
        echo "ATTENZIONE: file non trovato o vuoto: $fasta_path"
    fi
done < "$strains_file"

echo "Creato multi-species FASTA: $commonMultiFasta"
