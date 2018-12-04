#!/bin/bash -x
set -eu -o pipefail
bam=$1 #star_align/{sample}_Aligned.sortedByCoord.out.bam
gdir=$2
threads=$3
paired=$4 #0 is single and 1 paired
SID=$(basename $(dirname $bam))
pairopt=""
if (( $paired == 1 )); then
    pairopt="-p"
fi
   
featureCounts -a $gdir/genome.gtf -o featureCounts/$SID $pairopt -M --fraction $bam