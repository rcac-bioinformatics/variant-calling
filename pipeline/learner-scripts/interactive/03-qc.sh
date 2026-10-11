# Episode 3: read quality control in an interactive session
sinteractive -A rcac -q standby -p cpu -N 1 -n 4 --time=1:00:00
module load biocontainers
module load fastqc/0.12.1
module load multiqc/1.23
cd $SCRATCH/varcall-workshop
fastqc -t 4 -o results/qc data/*.fastq.gz
multiqc -o results/qc results/qc
ls results/qc
