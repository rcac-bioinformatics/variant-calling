# Episode 6: submit hap.py, then read its results after evaluate.sh has finished. Login node.
# Workshop: task 1 only (HG002 against v5.0q); the other three tasks come from the completed results
cd $SCRATCH/varcall-workshop/scripts
sbatch --array=1 evaluate.sh
cd $SCRATCH/varcall-workshop
ls results/eval/*.summary.csv
column -s, -t results/eval/HG002.v5.0q.norm.summary.csv | cut -c1-120
column -s, -t results/eval/HG002.v5.0q.filtered.summary.csv | cut -c1-120
column -s, -t results/eval/HG002.v4.2.1.filtered.summary.csv | cut -c1-120
