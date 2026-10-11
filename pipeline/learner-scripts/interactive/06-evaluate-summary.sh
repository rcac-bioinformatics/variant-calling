# Episode 6: read the hap.py results after evaluate.sh has finished. Login node.
cd $SCRATCH/varcall-workshop
ls results/eval/*.summary.csv
column -s, -t results/eval/HG002.v5.0q.norm.summary.csv | cut -c1-120
column -s, -t results/eval/HG002.v5.0q.filtered.summary.csv | cut -c1-120
column -s, -t results/eval/HG002.v4.2.1.filtered.summary.csv | cut -c1-120
