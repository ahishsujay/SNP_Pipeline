#!/bin/bash

get_input () {
	# Function for doing your getopts
	while getopts "a:b:r:eo:f:zvih" options
	do
		case "$options" in
			a) reads1=$OPTARG;; #Reads input1
			b) reads2=$OPTARG;; #Reads input2
			r) ref=$OPTARG;; #Reads ref genome
			e) realign=1;;
			o) output=$OPTARG;;
			f) millsFile=$OPTARG;;
			z) gunzip=1;;
			v) v=1;;
			i) index=1;;
			h) h=1;;
			*) echo "Invalid Option, Please select something else";;
		esac
	done

	if (( h ))
	then
		echo "The arguements are as follows; -a: Reads input for fasta file: pair1; -b: Reads input for fasta file: pair2; -r: Input for the reference genome file; -e: Perform realignment; -o: Specify output VCF file name; -f: MillsFile location specified; -z: Output VCF file will be gunzipped; -v: Verbose mode; -i: Indexes output BAM file; -h: Prints usage information;"
		exit
	fi
echo
return 0
}

check_files () {
	# Function for checking for presence of input files, reference genome,
	# and the output VCF file
	#
	# Input: File locations (string)
	# Output: True, if checks pass; False, if checks fail (bool)

	## If input1 exists or doesn't exist
	if (( v ))
	then
		echo "Checking input file 1, input file 2, reference genome and mills file."
	fi

	## If input1 exists or dosn't exist
	if [ -e "$reads1" ]
	then
		echo "Your input file1 is read."
	else
		echo "There is no input file1."
		flag=1
		return $flag
	fi

	## If input2 exists or doesn't exist
	if [ -e "$reads2" ]
	then
		echo "Your input file2 is read."

	else
		echo "There is no input file2."
		flag=1
		return $flag
	fi

	## If reference genome exists or doesn't exist
	if [ -e "$ref" ]
	then
		echo "Your reference genome exists."
	else
		echo "The reference genome does not exist."
		flag=1
		return $flag
	fi

	## If mills file exists or doesn't exist
	if [ -e "$millsFile" ]
	then
		echo "Mills File exists."
	else
		echo "Mills file doesn't exist."
		flag=1
		return $flag
	fi

	##If $output file exists
	if [ -f "$(pwd)"/output/"$output" ]
	then
		echo "The output file already exists."
		echo "Enter y if you want to overwrite the file. Enter n if you want to exit the bash script."
		read -r answer
		if [ "${answer}" == "y" ]
		then
			:
		else
			exit 1
		fi
	fi
return 0
}

prepare_temp () {
	# Preparing your temporary directory

	if (( v ))
	then
		echo "Preparing temporary directory and indexing the reference genome given."
	fi

	## If .bwt file already exists.
	if [ -e "${ref}".bwt ]
	then
		echo "File already exists. Continuing..."
	else
	bwa index "$ref"
	fi

echo
return 0
}


mapping () {
	# Function for the mapping step of the SNP-calling pipeline
	#
	# Input: File locations (string), Verbose flag (bool)
	# Output: File locations (string)

	if (( v ))
	then
		echo "Mapping of pipeline is running."
	fi

	## If .sam file already exists
	if [ -e "$(pwd)"/tmp/lane.sam ]
	then
		echo "File already exists. Continuing..."
	else
	bwa mem -R '@RG\tID:foo\tSM:bar\tLB:library1' "$ref" "$reads1" "$reads2" > "$(pwd)"/tmp/lane.sam
	fi

	## If .bam already exists
	if [ -e "$(pwd)"/lane_fixmate.bam ]
	then
		echo "File already exists. Continuing..."
	else
	samtools fixmate -O bam "$(pwd)"/tmp/lane.sam "$(pwd)"/tmp/lane_fixmate.bam
	fi

	## If sorted bam file exists
	if [ -e "$(pwd)"/tmp/lane_sorted.bam ]
	then
		echo "File already exists. Continuing..."
	else
	samtools sort -O bam -o "$(pwd)"/tmp/lane_sorted.bam -T "$(pwd)"/tmp/lane_temp "$(pwd)"/tmp/lane_fixmate.bam
	fi

echo
return 0
}


improvement () {
	# Function for improving the number of miscalls
	#
	# Input: File locations (string)
	# Output: File locations (string)

	if (( v ))
	then
		echo "Fasta file for indexing is being prepared. Dictionary being created."
	fi

	## If .fai file already exists.
	if [ -e "${ref}".fai ]
	then
		echo "File already exists. Continuing..."
	else
		samtools faidx "$ref" ###(For creating chr17.fa.fai file)
	fi

	## If dict file already exists.
	if [ -e "$(pwd)"/tmp/ref_dict.dict ]
	then
		echo "File already exists. Continuing..."
	else
		samtools dict "$ref" -o "$(pwd)"/tmp/ref_dict.dict ###(For creating dict file)
	fi

	## If indexed bam file exists
	if (( index ))
	then
		if [ -e "$(pwd)"/tmp/lane_sorted.bam.bai ]
		then
			echo "File alreadys exists. Continuing..."
		else
			samtools index "$(pwd)"/tmp/lane_sorted.bam "$(pwd)"/tmp/lane_sorted.bam.bai
		fi
	fi ###(For creating indexed bam file)

	##If user wants to perform realignment and types -e option
	if (( realign ))
	then
		if (( v ))
		then
			echo "Realignment is running."
		fi

	java -Xmx2g -jar GenomeAnalysisTK.jar -T RealignerTargetCreator -R "$ref" -I "$(pwd)"/tmp/lane_sorted.bam -o "$(pwd)"/tmp/lane.intervals --known "$millsFile" --log_to_file "asujay3_1.log"

	java -Xmx4g -jar GenomeAnalysisTK.jar -T IndelRealigner -R "$ref" -I "$(pwd)"/tmp/lane_sorted.bam -targetIntervals "$(pwd)"/tmp/lane.intervals -known "$millsFile" -o "$(pwd)"/tmp/lane_realigned.bam --filter_bases_not_stored --log_to_file "asujay3_2.log"
	fi

echo
return 0
}

call_variants () {
	# Function to call variants
	#
	# Input: File locations (string)
	# Ouput: None

	#mpileup to create BCF file
	##If realignment is performed

	if (( v ))
	then
		echo "Call variants of pipeline is running."
	fi

	if (( gunzip ))
	then
		if (( realign ))
		then
			bcftools mpileup -Ou -f "$ref" "$(pwd)"/tmp/lane_realigned.bam | bcftools call -vmO z -o "$(pwd)"/output/"$output".vcf.gz
		else
			bcftools mpileup -Ou -f "$ref" "$(pwd)"/tmp/lane_sorted.bam | bcftools call -vmO z -o "$(pwd)"/output/"$output".vcf.gz
		fi
	else
		if (( realign ))
		then
			bcftools mpileup -Ou -f "$ref" "$(pwd)"/tmp/lane_realigned.bam | bcftools call -vmO v -o "$(pwd)"/output/"$output".vcf
		else
			bcftools mpileup -Ou -f "$ref" "$(pwd)"/tmp/lane_sorted.bam | bcftools call -vmO v -o "$(pwd)"/output/"$output".vcf
		fi
	fi

echo
return 0
}

main() {
	# Function that defines the order in which functions will be called
	# You will see this construct and convention in a lot of structured code.
	# Add flow control as you see appropriate
	get_input "$@"

	## Exit if the file's don't exist
	check_files
	if [ "$flag" == "1" ]
	then
		exit
	fi

	prepare_temp
	mapping
	improvement
	call_variants

echo
return 0
}

# Calling the main function
main "$@"


bats_test (){
    command -v bats
}
