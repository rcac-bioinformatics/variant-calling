#!/bin/bash
# submit_guard.sh: submit_all.sh must FAIL before it creates or submits anything when SINGULARITY_BIND
# or APPTAINER_BIND is set (Part C, 2026-10-14); with both unset the guard must stay silent. Then the
# same checks on a copy without the guard must fail (mutation). Called by run_all.sh (REPO, WORK).
set -u
: "${REPO:?}" "${WORK:?}"
G=$WORK/guard; mkdir -p "$G/bin"
# no real SLURM calls from a test, not even --test-only
# shellcheck disable=SC2016  # $0 belongs to the stub script
for c in sbatch squeue sacct; do printf '#!/bin/sh\necho "stub $0: not called in tests" >&2\nexit 1\n' > "$G/bin/$c"; chmod +x "$G/bin/$c"; done
export PATH=$G/bin:$PATH

check() {  # repo copy -> prints results, exit 0 if every case holds
  local r=$1 ok=0 n=0 v out rc
  for v in SINGULARITY_BIND APPTAINER_BIND; do
    n=$((n + 1))
    out=$(env -u SINGULARITY_BIND -u APPTAINER_BIND "$v=/var/opt,/run/user" KIT_RUNS="$G/kit-runs" SCRATCH="$G/scratch" \
      bash "$r/negishi-run/submit_all.sh" --run guardtest --dry-run 2>&1); rc=$?
    if [ $rc -ne 0 ] && grep -q "FAIL: $v is set" <<< "$out" && [ ! -e "$G/kit-runs/guardtest" ]; then
      ok=$((ok + 1)); echo "  ok: $v set -> exit $rc, guard message, nothing created"
    else echo "  FAILED: $v set -> exit $rc"; fi
  done
  n=$((n + 1))
  out=$(env -u SINGULARITY_BIND -u APPTAINER_BIND KIT_RUNS="$G/kit-runs" SCRATCH="$G/scratch" \
    bash "$r/negishi-run/submit_all.sh" --run guardtest --dry-run 2>&1)
  if ! grep -q "is set in this shell" <<< "$out"; then ok=$((ok + 1)); echo "  ok: both unset -> no guard message"
  else echo "  FAILED: guard fired with both unset"; fi
  [ $ok -eq $n ]
}

pass=0
echo "guard, current submit_all.sh:"
if check "$REPO"; then pass=$((pass + 1)); fi
echo "guard, mutation (guard removed from a copy):"
rm -rf "$G/r"; mkdir -p "$G/r/negishi-run"
rsync -a --exclude records --exclude tests "$REPO/negishi-run/" "$G/r/negishi-run/"
rsync -a "$REPO/episodes" "$REPO/learners" "$REPO/pipeline" "$REPO/data-prep" "$G/r/"
python3 - "$G/r/negishi-run/submit_all.sh" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
a = s.index("for v in SINGULARITY_BIND APPTAINER_BIND; do"); b = s.index("done\n", a) + 5
open(p, "w").write(s[:a] + s[b:])
PY
if check "$G/r" > "$G/mutation.txt" 2>&1; then echo "  MISSED: the checks still pass without the guard"
else pass=$((pass + 1)); echo "  caught: $(grep -m1 FAILED "$G/mutation.txt" | sed 's/^ *//')"; fi
rm -rf "$G/r"
echo "submit guard: $pass of 2"
[ $pass -eq 2 ]
