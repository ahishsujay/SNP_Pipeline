# SNP_Pipeline

Pipeline for calling Single Nucleotide Polymorphisms (SNPs). The pipeline is written in bash.

## Variant/SNP calling pipeline steps:
1.	Align FASTQ reads to a reference genome to create an alignment file - Mapping step
2.	Processing the alignment file (file format conversion, sorting, alignment improvement) - Improvement step
3.	Calling the variants - Variant Calling step

## Pipeline Requirements:
1.	[bwa](https://github.com/lh3/bwa) for the alignment
2.	[samtools/HTS](http://www.htslib.org/) package for processing and calling variants
3.	[GATK](https://gatk.broadinstitute.org/hc/en-us) for improving the alignment. You must use GATK v3.7.0, available on the Archived version page

## Input command line options:
- -a	Input reads file – pair 1
- -b	Input reads file – pair 2
- -r	Reference genome file
- -e	Perform read re-alignment
- -o	Output VCF file name
- -f	Mills file location
- -z	Output VCF file should be gunzipped (*.vcf.gz)
- -v	Verbose mode; print each instruction/command to tell the user what your script is doing right now
- -i	Index your output BAM file (using samtools index)
- -h	Print usage information (how to run your script and the arguments it takes in) and exit

## Required input files:
1. Input reads file - pair1
2. Input reads file - pair2
3. Reference genome file
4. Mills file

## Execution of the bash script:
./snp_pipeline.bash -a <input reads file -pair1> -b <input reads file -pair2> -r <reference genome file> -f <Mills file> -o <output file>

## Output file:
VCF File
