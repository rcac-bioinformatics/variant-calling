#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:30:00
# session: one interactive block (pipeline/learner-scripts/interactive/NN-name.sh) as a learner
# types it, in a batch job with the block's own cores and time. Needs RUN_ID, STEP, BLOCK, COPY.
set -euo pipefail
# shellcheck source=pipeline/lib.sh
source "${PIPE_DIR:?PIPE_DIR must be exported by the submitter}/lib.sh"
kit_job_begin "${STEP:?}"
t0=$(date +%s)
run_block "$STEP" "${BLOCK:?}" "${COPY:?}"
kit_metric "$STEP" "$COPY" wall_s_block "$(( $(date +%s) - t0 ))" s
kit_job_end
