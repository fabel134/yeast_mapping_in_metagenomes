#!/bin/bash

set -x
source "$(pwd)/config"

commonMultiFasta="$multiFastaDir"/multi_species.fa
filename=$(basename "$commonMultiFasta")
nameID="${filename%.fa}"
infoseq -delimiter "\t" -only -noheading -name -length "${commonMultiFasta}" >> "${lengthChrsDir}/${nameID}.chrs.len"
echo "Creato: ${lengthChrsDir}/${nameID}.chrs.len"
