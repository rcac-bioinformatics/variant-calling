# Episode 2: copy the workshop data and link the shared reference. Login node.
echo $SCRATCH
mkdir -p $SCRATCH/varcall-workshop
rsync -av /depot/workshop/data/varcall-workshop/ $SCRATCH/varcall-workshop/
cd $SCRATCH/varcall-workshop
mkdir -p ref results/qc results/bam results/qc_alignment results/vcf results/eval results/annot results/trio
# The reference and its indexes stay read-only on Depot; link them instead of copying them
ln -s /depot/workshop/data/varcall-workshop_ref/* ref/
ls -l ref/
ls data/ resources/ scripts/
# Check that the FASTQ files arrived intact
cd data
md5sum -c md5sums.txt
cd ..
head data/samples.tsv
cat data/trio.ped
