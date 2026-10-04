#!/bin/bash
# Re-run dist-199.sh until it reports DONE (each run already retries x.py 6 times).
# Waits for an already-running dist-199.sh first. Keeps all build output between runs.
R=~/rust; S=$R/status-dist; L=$R/status-loop
for run in $(seq 1 10); do
  while ps | grep -v grep | grep -q 'dist-199.sh'; do sleep 60; done
  last=$(tail -1 $S 2>/dev/null)
  [ "$last" = DONE ] && { echo "DONE after run $run $(date +%T)" >> $L; exit 0; }
  echo "run $run: last=[$last] restarting $(date +%T)" >> $L
  [ -f $S ] && mv $S $S.loop$run
  nohup $R/dist-199.sh </dev/null >/dev/null 2>&1 &
  sleep 30
done
echo "GAVE UP $(date +%T)" >> $L
