#!/usr/bin/env bash

### Automated the annotation of Trinity transcriptome assemblies via the Trinotate pipeline
### This script is meant to be run in a directory containing at least one Trinity assembly
### Since the for loop will operate on any file ending in .fasta, best to run it in a directory with just the Trinity assemblies you are interested in annotating
### $PATH for executables and DBs used by this script are hardcoded to The Molette Lab server SkyNet, so modify those accordingly to your situation
### printf statements in the for loop append start times of each step to a log in the parent directory where the script was executed
### Written November 17th, 2013 by S.R. Santos, Department of Biological Sciences, Auburn University
### Edited by Kerry Cobb 29 May 2019




### Keep bash shell from globbing unless explicitly told to
shopt -s nullglob

### Add the paths to required tools to the PATH environmnet variable
module load transdecoder
module load blast+
module load hmmer
module load tmhmm
module load signalp

### Start looping through the Trinity assemblies that are *.fasta files
for FILENAME in *.fasta
do
	### Create a variable for the date and species whose transcriptome is being annotated and set up a specific directory for the annotation to be done in (keeps things tidy)
	### This will need to be modified depending on the specifics of your FASTA descriptor
	MTHYR=`date | awk '{print ($2$6)}'`
	SPECIES=`head -1 $FILENAME | sed -e 's/>//;s/_TRI_.*$//;s/_RAY_.*$//'`
	mkdir ${SPECIES}_Trinotate_${MTHYR}
	mv $FILENAME ${SPECIES}_Trinotate_${MTHYR}
	cd ${SPECIES}_Trinotate_${MTHYR}
	PARENT_DIR=`pwd | awk -F"/" {'print $(NF-1)'}`

  ### Extract the most likely longest-ORF peptide candidates from the Trinity assembly using TransDecoder and remove the empty tmp directory when done
	printf "Started transdecoder for ${SPECIES} on `date` ......\n" >> ../Trinotate_run_${PARENT_DIR}_${MTHYR}.log
	# ${TRANSDECODER} -t $FILENAME
  	TransDecoder.LongOrfs -t $FILENAME
	TransDecoder.Predicct -t $FILENAME
	rm -rf *.tmp*

  ### BLAST the raw transcripts (blastx) and peptide candidates (blastp) against the UNIProt database; save single best hit in tab delimited format
  	printf "Started blastp for ${SPECIES} on `date` ......\n" >> ../Trinotate_run_${PARENT_DIR}_${MTHYR}.log
  	blastp -query ${FILENAME}.transdecoder.pep -db /home/shared/biobootcamp/data/uniprot_sprot/uniprot_sprot.fasta -num_threads 4 -max_target_seqs 1 -outfmt 6 > ${SPECIES}_blastp.outfmt6
	printf "Started blastx for ${SPECIES} on `date` ......\n" >> ../Trinotate_run_${PARENT_DIR}_${MTHYR}.log
	blastx -query $FILENAME -db /home/shared/biobootcamp/data/uniprot_sprot/uniprot_sprot.fasta -num_threads 4 -max_target_seqs 1 -outfmt 6 > ${SPECIES}_blastx.outfmt6

  ### Run HMMER to identify protein domains in the most likely longest-ORF peptide candidates from the Trinity assembly
	printf "Started hmmscan for ${SPECIES} on `date` ......\n" >> ../Trinotate_run_${PARENT_DIR}_${MTHYR}.log
	hmmscan --cpu 10 --domtblout ${SPECIES}_TrinotatePFAM.out /home/shared/biobootcamp/data/Pfam-A/Pfam-A.hmm ${FILENAME}.transdecoder.pep > ${SPECIES}_pfam.log

  ### Run signalP to predict signal peptides in the most likely longest-ORF peptide candidates from the Trinity assembly
	printf "Started signalp for ${SPECIES} on `date` ......\n" >> ../Trinotate_run_${PARENT_DIR}_${MTHYR}.log
	signalp -f short -n ${SPECIES}_signalp.out ${FILENAME}.transdecoder.pep

  ### Run tmHMM to predict transmembrane regions in the most likely longest-ORF peptide candidates from the Trinity assembly
	printf "Started tmhmm for ${SPECIES} on `date` ......\n" >> ../Trinotate_run_${PARENT_DIR}_${MTHYR}.log
	tmhmm --short < ${FILENAME}.transdecoder.pep > ${SPECIES}_tmhmm.out

  ### Remove the empty tmp directory left by tmhmm and move up into the parent directory
	rm -rf TMHMM_*
	printf "DONE - Trinotate annotation of ${SPECIES} completed at `date` \n" >> ../Trinotate_run_${PARENT_DIR}_${MTHYR}.log
	cd ..

  ### Now tar.gz to save space and delete original directory/files
	tar -pczf ${SPECIES}_Trinotate_${MTHYR}.tar.gz ${SPECIES}_Trinotate_${MTHYR}/
	rm -rf ${SPECIES}_Trinotate_${MTHYR}/
	### Now continue back to beginning of da_loop for any remaining Trinity assemblies
done
