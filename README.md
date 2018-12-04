# snakemake implementation of MoTrPAC RNA-seq pipeline
**Contact:** Yongchao Ge (yognchao.ge@mssm.edu)

The initial MoTrPAC RNA-seq MOP: https://docs.google.com/document/d/1oz8jZAY9Rq4uqenp-0RMkQBhMtjsMLKlxfjlmRExSQ0/edit?ts=5b04a52e#

## A. External softwares installation and bash environmental setup

### A.1 Conda installation 
We are heavily relying on conda to install/update many bioinformatics software with the same fixed versions. Most updated softwares are available at conda https://conda.io/miniconda.html . 
*   Install the python2 and python3 under the conda root folder `$conda` following the instructions at [conda_install.sh](bin/conda_install.sh)
*   The last command at the file `conda_install.sh` installs the specified versions of software packages and their dependency packages.
https://github.com/yongchao/motrpac/blob/2889fda8676128e1a7b2b7ecc5b6214b1d12e6c6/bin/conda_install.sh#L28-L39
```bash
conda install \
      python=3.6.6 \
      snakemake=5.3.0\
      star=2.6.1b\
      cutadapt=1.18 \
      picard=2.18.16 \
      samtools=1.3.1 \
      r-base=3.4.1 \
      rsem=1.3.1 \
      multiqc=1.6 \
      bowtie2=2.3.4.3\
      fastqc=0.11.8
```

### A.2 bash environments setup
We rely on the same set-up of conda installation folder structures so that the dependency softwares/packages (with the same versions) are portable. We need to setup some soft links under `MOTRPAC_ROOT` and  export the environmental variables `MOTRPAC_ROOT` and `PATH`
*   `MOTRPAC_ROOT` is the root folder of the github code 
*    Under the `MOTRPAC_ROOT` subfolder, we need to setup the softlinks below
     *   `refdata` soft link that points to the genome data index folder. e.g. `cd $MOTRPAC_ROOT; ln -s $refdata .`
	 *   `conda` soft link that points to conda installation folder. e.g. `cd $MOTRPAC_ROOT; ln -s $conda .`
	 *   `tmpdir` soft link that points to a temporary folder that has at least 100G of free space
* `  export $(bin/load_motrpac.sh)`will export the environment variables `MOTRPAC_ROOT` and `PATH`

### A.3 download the genome source and build the refdata
*  Download the genome source data (fa and gtf from gencode and ensembl) and also build the bowtie2\_index for the miscellaneous small data (globin and rRNA)
  [source\_data.sh](bin/source_data.sh)
*  Make sure the gtf file and fa file from ensembl have "chr" as part of the chromosome name as in gencode data (see [fixchr4ensembl.sh](bin/fixchr4ensembl.sh))
*  Sort the gtf file accordingly, these are in the file [genome.sh](bin/genome.sh)
*  Build the genome reference data
     *   [bowtie\_index](bin/bowtie_index.sh)
	 *   [star\_index](bin/star_index.sh)
	 *   [bowtie2\_index](bin/bowite2_index.sh)
     *   [rsem\_index](bin/rsem_index.sh)

	 
For each genome folder that was downloaded by [source\_data.sh](bin/source_data.sh). The genome data and index for the refdata can be built at the refdata with the command, for example hg38_gencode_v29
``` cd  $MOTRPAC_ROOT/refdata/hg38_gencode_v29
	snakemake -s $MOTRPAC_ROOT/genome_index.snakmake
```

```bash
NUM_THREADS=10
OVERHANG=99 # for 2x75 NextSeq and MiSeq runs

STAR \
	--runThreadN $NUM_THREADS \
	--runMode genomeGenerate \
	--genomeDir $INDEX_DIRECTORY \
	--genomeFastaFiles $GENOME_FASTA \
	--sjdbGTFfile $GTF_FILE \
	--sjdbOverhang $OVERHANG
```

# A. bcl2fastq
    [bcl2fastq.sh](bin/bcl2fastq.sh) generates three fastq files, R1, I1 and R2.
	All of the fastq files can be softlinked with `${SID}_R1.fastq.gz`, `${SID}_I1.fastq.gz` and `${SID}_I1.fastq.gz`, where `SID` is the sample id. And all of these files are saved in the sub folder `fastq_raw`
# B.  Pre-alignment sample processing and QC

### A1.1 Run FASTQC on all FASTQ files on the fastq file in fastq_raw folder
## A.2 Adapter trimming

For each paired-end FASTQ file (`${SAMPLE}\_R1_001.fastq.gz` and `${SAMPLE}\_R2_001.fastq.gz`), remove adapters (set using INDEXED_ADAPTER_PREFIX and UNIVERSAL_ADAPTER) using cutadapt v1.16. Eliminate reads that are too short after removing adapters and save trimmed FASTQ files (`${SAMPLE}\_R1_001.trimmed.fastq.gz` and `${SAMPLE}\_R2_001.trimmed.fastq.gz`). Save reads that were trimmed because they were too short in `${prefix}_R[1-2]_001.tooshort.fastq.gz`.  

Parameters:  

* `FASTQ_DIR`: Input directory that contains FASTQ files. The following code assumes that it contains gzipped, paired R1 and R2 files for each sample.  
* `OUTPUT_DIR`: Output directory for trimmed FASTQ files  
* `m`: Remove reads that are this short after removing adapters, e.g. m=50 bp for 150 bp reads and m=20 bp for 75 bp reads

```bash
# for NUGEN kits (Illumina TruSeq adapters):
INDEXED_ADAPTER_PREFIX=AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC
UNIVERSAL_ADAPTER=AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGTAGATCTCGGTGGTCGCCGTATCATT

for prefix in `ls ${FASTQ_DIR} | grep "fastq.gz" |  grep -v "_I1_" | sed "s/_R[0-9]_001\..*//" | uniq`; do 
	r1=`ls ${indir} | grep ${prefix} | grep "R1_001.fastq.gz"`
	r2=`ls ${indir} | grep ${prefix} | grep "R2_001.fastq.gz"`

	cutadapt \
		-a $INDEXED_ADAPTER_PREFIX \
		-A $UNIVERSAL_ADAPTER \
		-o ${OUTPUT_DIR}/${prefix}_R1_001.trimmed.fastq.gz -p ${OUTPUT_DIR}/${prefix}_R2_001.trimmed.fastq.gz \
		-m 20 \
		--too-short-output ${OUTPUT_DIR}/${prefix}_R1_001.tooshort.fastq.gz \
		--too-short-paired-output ${OUTPUT_DIR}/${prefix}_R2_001.tooshort.fastq.gz \
 		${FASTQ_DIR}/${r1} ${FASTQ_DIR}/${r2} 
done
```
### A1.1 Run FASTQC on all FASTQ files on the fastq file in fastq_trim folder

### A.1.2 MultiQC for pre-aligned data, collecting the QC metrics on the fastqc, fastqc_raw and fastq\_trim folders

Parameters:  

* `OUTPUT_DIR`: Output folder for MultiQC report
* `FASTQC_DIR_N`: Directory/directories containing FASTQC reports from the previous step. Include as many directories as needed (minimum 1).

Options:  

* `-d`: Prepend the directory to file names (useful for keeping track of samples in multiple runs)  
* `-f`: Overwrite existing MultiQC reports in `OUTPUT_DIR`  

```bash
multiqc \
	-d \
	-f \
	-n $REPORT_NAME \
	-o $OUTPUT_DIR \
	$FASTQC_DIR_1 \
	$FASTQC_DIR_2 
```




## B.2 Alignment 

Align each trimmed FASTQ file to the reference using STAR.  

Parameters:  

* `GTF_FILE`: Same file as in step B.1
* `INDEX_DIRECTORY`: Path to genome index from step B.1  
* `TRIMMED_FASTQ_DIR`: Folder containing trimmed FASTQ files (step A.2) 
* `OUTPUT_DIR`: Directory for output of STAR alignment, including sorted BAM files

```bash
for prefix in `ls ${TRIMMED_FASTQ_DIR} | grep "fastq.gz" | sed "s/_R[0-9]_001\..*//" | uniq`; do 

	r1=`ls ${TRIMMED_FASTQ_DIR} | grep ${prefix} | grep "R1_001.trimmed.fastq.gz"`
	r2=`ls ${TRIMMED_FASTQ_DIR} | grep ${prefix} | grep "R2_001.trimmed.fastq.gz"`

	STAR \
		--genomeDir $INDEX_DIRECTORY \
		--readFilesIn ${TRIMMED_FASTQ_DIR}/${r1} ${TRIMMED_FASTQ_DIR}/${r2} \
		--outFileNamePrefix ${OUTPUT_DIR}/${prefix}_ \
		--readFilesCommand zcat \
		--outSAMattributes NH HI AS NM MD nM\
		--outFilterType BySJout \
		--runThreadN 8 \
		--outSAMtype BAM SortedByCoordinate \
		--quantMode TranscriptomeSAM\
		--genomeLoad LoadAndKeep \
		--limitBAMsortRAM 15000000000 
done
```

## B.3 Quantification

Use RSEM v. 1.3.1 for quantification to obtain gene-level and transcript-level quantification

### B.3.1 Prepare RSEM reference

First, prepare the RSEM reference. This only needs to be done once.  

Parameters:  

* `OUTPUT_PREFIX`: Output prefix for RSEM reference, including output directory. i.e. `OUTPUT_PREFIX=${OUTPUT_DIR}/${PREFIX}`  
* `GENOME_FASTA` and `GTF_FILE` are the same as in step B.1  

```bash 
$PATH_TO_RSEM/rsem-prepare-reference \
	--gtf $GTF_FILE \
	$GENOME_FASTA \
	$OUTPUT_PREFIX
```

### B.3.2 Run quantification 

Now run quantification with the sorted `*Aligned.toTranscriptome.sorted.bam` files.  

Parameters:  

* `ALIGNED_IN`: Input directory of aligned BAM files  
* `RSEM_REFERENCE`: Same as `OUTPUT_PREFIX` in the previous step (B.3.1)  
* `OUTPUT_DIR`: Output directory for quantification stats  

```bash 
for sample in `ls ${ALIGNED_IN} | grep "Aligned.toTranscriptome.out.bam" | sed "s/_Aligned.*//" | sort | uniq`; do

	bam_file=${ALIGNED_IN}/${sample}_Aligned.toTranscriptome.out.bam

	$PATH_TO_RSEM/rsem-calculate-expression \
		-p 12 \
		--bam \
		--paired-end \
		--no-bam-output \
		--forward-prob 0.5 \
		--seed 12345 \
		${bam_file} \
		${RSEM_REFERENCE} \
		${OUTPUT_DIR}/${sample}

	done
done
```

## B.4 Post-alignment QC

### B.4.1 RNA-seq metrics with Picard CollectRnaSeqMetrics

Compute post alignment QC metrics, including % mapped to coding, intron, intergenic, UTR, and % correct strand, and 5’ to 3’ bias.  

refFlat files are required for this step, which can be generated from GTF files. Human (gencode.v29.annotation.refFlat) and rat (Rattus_norvegicus.Rnor_6.0.94.refFlat) refFlat files are provided in the `data` directory of this repostitory, generated from the GTF files specified in step B.1. See the README file in the `data` directory for more information on how these files were generated.

Parameters:  

* `REF_FLAT`: Gene annotations in refFlat format  
* `BAM_DIR`: Path to BAM files output by STAR in step B.2 
* `OUTPUT_DIR`: Output directory for RNA-seq metrics   

```bash
for sample in `ls $BAM_DIR | grep "Aligned.sortedByCoord.out.bam" | sed "s/_Aligned.*//" | sort | uniq`; do

	bam=${BAM_DIR}/${sample}_Aligned.sortedByCoord.out.bam

	java -Xmx10g -jar picard.jar CollectRnaSeqMetrics \
		I=$bam  \
		O=$OUTPUT_DIR/${sample}_output.RNA_Metrics \
		REF_FLAT=$REF_FLAT \
		STRAND=FIRST_READ_TRANSCRIPTION_STRAND 
done
```

### B.4.2 Count alignments by segment 

Calculate the number of reads mapped to chromosomal, mitochondial, and contiguous regions. Note that these metrics have to be parsed differently for human and rat samples given their disparate GTF file formats. The following code will work if the BAM files followed from the workflow provided in this README.  

This section outputs a single file in `${INDIR}` called `merged.regional.read.counts.txt` with the following columns:  

* `SAMPLE`: Prefix of ${PREFIX}\_Aligned.sortedByCoord.out.bam
* `TOTAL_READS`: Total mapped reads
* `CHROM_READS`: Number of reads mapped to chromosomes (autosomal and sex)
* `MITO_READS`: Number of reads mapped to the mitochondrial chromosome
* `CONTIG_READS`: Number of reads mapped to contigs 

Parameters:  

* `INDIR`: Directory containing ${SAMPLE}\_Aligned.sortedByChrom.out.bam files from step B.2  
* `hs_sample`: An array of prefixes for human samples, e.g. `hs_sample=( HUMAN_PBMC_S1 HUMAN_PBMC_S2 HUMAN_MUSCLE_S3 )`, such that BAM files are named ${PREFIX}\_Aligned.sortedByCoord.out.bam
* `rat_sample`: An array of prefixes for rat samples, e.g. `rat_sample=( RAT_LIVER_S1 RAT_GASTROC_S2 RAT_BLOOD_S3 )`, such that BAM files are named ${PREFIX}\_Aligned.sortedByCoord.out.bam

```bash
echo "SAMPLE	TOTAL_READS	CHROM_READS	MITO_READS	CONTIG_READS" > ${INDIR}/merged.regional.read.counts.txt

# only for human samples

for sample in "${hs_sample[@]}"; do 

	file=${sample}_Aligned.sortedByCoord.out.bam
	
	# get table of reads per segment
	samtools view ${INDIR}/${file} | cut -f3 | sort | uniq -c > ${INDIR}/tmp.${sample}.read.cnts
	# get total
	total=`sed "s/^[ \t]*//" ${INDIR}/tmp.${sample}.read.cnts | cut -d' ' -f1 | awk '{total += $0} END{print total}'`
	# get num chromosomal
	chrom=`grep "chr[1-9XY]" ${INDIR}/tmp.${sample}.read.cnts | sed "s/^[ \t]*//" | cut -d' ' -f1 | awk '{total += $0} END{print total}'`
	# get num mitochondrial
	mito=`grep "chrM" ${INDIR}/tmp.${sample}.read.cnts | sed "s/^[ \t]*//" | cut -d' ' -f1 | awk '{total += $0} END{print total}'`
	# get num on contigs
	contig=`grep -v "chr" ${INDIR}/tmp.${sample}.read.cnts | sed "s/^[ \t]*//" | cut -d' ' -f1 | awk '{total += $0} END{print total}'`

	echo "$sample	$total	$chrom	$mito	$contig" >> ${INDIR}/merged.regional.read.counts.txt

done

# only for rat samples

for sample in "${rat_sample[@]}"; do 

	file=${sample}_Aligned.sortedByCoord.out.bam

	# get table of reads per chromosome
	samtools view ${indir}/${file} | cut -f3 | sort | uniq -c > ${INDIR}/tmp.${sample}.read.cnts
	# get total
	total=`sed "s/^[ \t]*//" ${INDIR}/tmp.${sample}.read.cnts | cut -d' ' -f1 | awk '{total += $0} END{print total}'`
	# get num chromosomal
	head -20 ${INDIR}/tmp.${sample}.read.cnts > ${INDIR}/tmp.${sample}.chrom
	tail -2 ${INDIR}/tmp.${sample}.read.cnts >> ${INDIR}/tmp.${sample}.chrom
	chrom=`sed "s/^[ \t]*//" ${INDIR}/tmp.${sample}.chrom | cut -d' ' -f1 | awk '{total += $0} END{print total}'`
	# get num mitochondrial
	mito=`grep -E " MT$" ${INDIR}/tmp.${sample}.read.cnts | sed "s/^[ \t]*//" | cut -d' ' -f1 | awk '{total += $0} END{print total}'`
	# get num on contigs
	contig=`tail -n +21 ${INDIR}/tmp.${sample}.read.cnts | head -n -3 | sed "s/^[ \t]*//" | cut -d' ' -f1 | awk '{total += $0} END{print total}'`
	echo "$sample	$total	$chrom	$mito	$contig" >> ${INDIR}/merged.regional.read.counts.txt

done

rm ${INDIR}/tmp* # remove temporary files created in intermediate steps
```

### B.4.3 Calculate % contamininants (rRNA and globin)

Map the original FASTQ files against the species-specific ribosomal RNA and hemoglobin sequences to get the number of reads that map to rRNA and globin. 

See the `*.fa` files in the `data` directory of this repository for rat and human rRNA and globin FASTA files. The README in the `data` directory details how these files were generated.  

#### B.4.3.1 Build bowtie indices for rRNA and globin FASTA files  

Run the following command to build bowtie2 indices for each FASTA file, where `INDEX_PREFIX` includes the path to the output directory plus a prefix for the index (e.g. `/PATH/TO/OUTDIR/rn6_globin`):  

```bash
bowtie2-build $FASTA_FILE $INDEX_PREFIX 
``` 
#### B.4.3.2 Align raw FASTQ files to rRNA and globin bowtie2 indices  

Once the indices are built for both globin and rRNA, run the following code to map each BAM file to the contaminant FASTA files. This step will generate a SAM file and an alignment stat file for each sample. The *merge results* section of the code produces `merged_rRNA.log` and `merged_globin.log` summary files to provide % reads mapped to each sample.  

The following codeassumes that the paired FASTQ files are named with the format `ANY_SAMPLE_NAME_R1_001.fastq.gz` and `ANY_SAMPLE_NAME_R2_001.fastq.gz`. 

Parameters:  

* `RRNA_REF`: Path to rRNA bowtie2 index (same as `$INDEX_PREFIX` above)  
* `GLOBIN_REF`: Path to globin bowtie2 index (same as `$INDEX_PREFIX` above)  
* `OUTDIR`: Output directory for SAM file and alignment stats  
* `INDIR`: Directory with raw FASTQ files  

```bash
for prefix in `ls ${INDIR} | grep "fastq.gz" | grep -v "Undetermined" | grep -v "_I1_" | sed "s/_R[0-9]_001\..*//" | uniq`; do
	r1=${INDIR}/${prefix}_R1_001.fastq.gz
	r2=${INDIR}/${prefix}_R2_001.fastq.gz

	bowtie2 --local -p 20 -s --sam-nohead -x $RRNA_REF \
		-1 $r1 -2 $r2 >${OUTDIR}/${prefix}_rRNA.sam  2>${OUTDIR}/${prefix}_rRNA.log

	bowtie2 --local -p 20 -s --sam-nohead -x $GLOBIN_REF \
		-1 $r1 -2 $r2 >${OUTDIR}/${prefix}_globin.sam  2>${OUTDIR}/${prefix}_globin.log
done

# merge results

for file in `ls $OUTDIR | grep "rRNA.log"`; do 
	prefix=`echo $file | sed "s/_rRNA.*//"`
	alignment=`tail -1 $file`; echo "$prefix	$alignment" >> $OUTDIR/merged_rRNA.log
done

for file in `ls $OUTDIR | grep "globin.log"`; do 
	prefix=`echo $file | sed "s/_globin.*//"`
	alignment=`tail -1 $file`; echo "$prefix	$alignment" >> $OUTDIR/merged_globin.log
done
```

# C. Compile important metrics

The metrics in Section C can be determined the same way for both human and rat samples from outputs from the preceding steps.

## C.1 Summarize alignment metrics from STAR with MultiQC

Compile the metrics from the Log.final.out files into a single MultiQC report.  

These metrics include:  

* Number of total reads  
* Average read length  
* Average mapping length  
* Number (or percentage) of uniquely mapped reads  
* Multi-mapped reads( too many loci, multiple loci)  
* Unmapped reads (too many mismatches, too short, other)  
* Chimeric reads  

Parameters:  

* `OUTPUT_DIR`: Output folder for MultiQC report
* `FASTQC_DIR_N`: Directory/directories containing STAR log files from alignment. Include as many directories as needed (minimum 1).

Options:  

* `-d`: Prepend the directory to file names (useful for keeping track of samples in multiple runs)  
* `-f`: Overwrite existing MultiQC reports in `OUTPUT_DIR`  

```bash
multiqc \
	-d \
	-f \
	-n $REPORT_NAME \
	-o $OUTPUT_DIR \
	$FASTQC_DIR_1 \
	$FASTQC_DIR_2 
```
## C.2 Mark PCR duplicates

For each bam file, mark PCR duplicates using Picard tools. 

Parameters:  

* `BAM_DIR`: Directory containing ${SAMPLE}\_Aligned.sortedByChrom.out.bam files from step B.2  
* `OUTDIR`: Output directory for metrics file  

```bash 
for sample in `ls $BAM_DIR | grep "Aligned.sortedByCoord.out.bam" | sed "s/_Aligned.*//" | sort | uniq`; do

	bam=${BAM_DIR}/${sample}_Aligned.sortedByCoord.out.bam

	java -Xmx10g -jar picard.jar MarkDuplicates \
		INPUT=$bam \
		OUTPUT=${BAM_DIR}/${sample}.markedDup \
		CREATE_INDEX=true \
		VALIDATION_STRINGENCY=SILENT \
		METRICS_FILE=${OUTDIR}/${sample}.markedDup.out \
		REMOVE_DUPLICATES=false 
done 
```

## C.3 Compile important metrics into a single report 

### C.3.1 FASTQ metrics (raw and trimmed)

* PCT_GC: FASTQC metric from raw FASTQ files (take the average of the two values from the read pair)
* READ_CNT_RAW: number of reads in raw FASTQs for each sample (i.e. the line count of SAMPLE_R1_001.fastq divided by 2)
* READ_CNT_TRIMMED: number of reads in trimmed FASTQs for each sample (i.e. the line count of SAMPLE_R1_001.trimmed.fastq divided by 2)

### C.3.2 Contamination metrics (step B.4.4.2)

* PCT_RRNA: from merged_rRNA.log
* PCT_GLOBIN: from merged_globin.log

### C.3.3 Post-alignment RNA-seq metrics from Picard's CollectRnaSeqMetrics output files (step B.4.1)

* PCT_EXONIC: (PCT_CODING_BASES + PCT_UTR_BASES)\*100 
* PCT_INTRONIC: PCT_INTRONIC_BASES 
* PCT_INTERGENIC: PCT_INTERGENIC_BASES
* PCT_CORRECT_STRAND: PCT_CORRECT_STRAND_READS
* 5_3_BIAS: MEDIAN_5PRIME_TO_3PRIME_BIAS

### C.3.4 Alignment metrics from STAR's ${SAMPLE}\_Log.final.out files (step B.2)

* READ_CNT_PAIRED_INPUT: `Number of input reads` 
* READ_CNT_MAPPED_UNIQ: `Uniquely mapped reads number`
* PCT_MAPPED_UNIQ: `Uniquely mapped reads %`
* READ_CNT_MAPPED_MULTI: `Number of reads mapped to multiple loci`
* PCT_MAPPED_MULTI: `% of reads mapped to multiple loci`
* READ_COUNT_TOO_MANY_MULTI: `Number of reads mapped to too many loci`
* PCT_TOO_MANY_MULTI: `% of reads mapped to too many loci`

### C.3.5 Alignment metrics from RSEM ${SAMPLE}.stat/${SAMPLE}.cnt files (step B.3.2)

* N_ALIGNABLE: line 1, col 2 (space-delimited)
* N_UNIQUE: line 2, col 1 (space-delimited)
* N_MULTI: line 2, col 2 (space-delimited)
* N_UNCERTAIN: line 2, col 3 (space-delimited)
* N_TOTAL_ALIGNMENTS: line 3, col 1 (space-delimited)

### C.3.6 Alignment metrics from merged.regional.read.counts.txt (step B.4.3)

* TOTAL_MAPPED: TOTAL_READS
* MAPPED_CHROM: CHROM_READS
* MAPPED_MT: MITO_READS
* MAPPED_CONTIG: CONTIG_READS 

### C.3.7 PCR duplicate metrics from ${SAMPLE}.markedDup.out (step C.2)

* TBD 

# D. Flag problematic samples

*These metrics are very liberal to remove samples of very low quality. Additional samples might be removed downstream using more stringent criteria.*

Flag samples with 

1. Low RIN scores, e.g. RIN < 6
2. Low number of sequenced reads after trimming adaptors, e.g. samples with < 20M reads
3. Abnormal GC content, e.g. GC% > 80% or < 20%
4. High percentage of rRNA, e.g. rRNA > 20%
5. Low number of mapped reads, e.g. < 60%
6. Low number of % exonic read, % exonic read < 50%
7. Mapped read count < 50% of average mapped read count per sample  

# E. Post-Quantification QC 

*These steps should be updated when new samples become available because they are depend on all samples.*

1. Confirm sample concordance with other omics genotypes from same individual using VerifyBAMID.
2. Obtain filtered and normalized expression data and filter outliers:  

  * Remove genes with 0 counts in every sample. 
  * Filter lowly expressed genes (for QC purposes only, definition of expressed gene might change for each analyses): genes with mean counts < 5 and zero counts in more than 20% of samples.
  * Perform library size correction and variance stabilization using DESeq2 or other methods.
  * Compute D-statistic for each sample based on filtered and normalized expression data, i.e. average Spearman’s correlation with other samples from the same tissue and time point. Flag samples with D<.80.
  * Perform PCA based on filtered and normalized expression data across and within tissues. Mark outlier samples (outside +/- 3 sd).  
