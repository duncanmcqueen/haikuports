# Sourced by chain.sh and dist-199.sh. Needs $S (status file).
# The beta6 VM sometimes writes whole 4 KiB pages of wrong data into large build
# outputs (.rlib members, objects). Seen as: rustc metadata ICE (STR_SENTINEL),
# ld "bad reloc symbol index", ld "out of memory allocating <huge>", "rlib format".
# The build is deterministic, so delete the damaged outputs and retry.
CORRUPT_RE='STR_SENTINEL|invalid enum variant tag|compiler unexpectedly panicked|bad reloc|error adding symbols|file format not recognized|file truncated|malformed|required to be available in rlib format|out of memory allocating [0-9]{10,}|invalid metadata|failed to decode'
# Haiku also sometimes leaves rustc threads stuck in an unnamed state (ps -a shows
# "???", ps -a itself blocks) with zero CPU. Watchdog: log not growing for 10 min
# and load < 0.3 at three 2-minute checks -> kill rustc, retry.
run_watched() {  # run_watched <log> <x.py args...>
  local log=$1; shift
  rm -f $log.hung
  ./x.py "$@" > $log 2>&1 &
  local pid=$! last=-1 still=0 idle=0 size load
  while kill -0 $pid 2>/dev/null; do
    sleep 120
    size=$(stat -c %s $log 2>/dev/null || echo 0)
    if [ "$size" = "$last" ]; then still=$((still+2)); else still=0; last=$size; fi
    load=$(uptime | sed 's/.*load average: *//; s/,.*//')
    if [ $still -ge 10 ] && awk -v l="$load" 'BEGIN{exit !(l<0.3)}'; then idle=$((idle+1)); else idle=0; fi
    if [ $idle -ge 3 ]; then
      touch $log.hung
      echo "HANG detected: log idle ${still}m load=$load $(date +%T)" >> $S
      ps | grep -E 'rustc --crate-name|build/bootstrap/debug/bootstrap' | grep -v grep | awk '{print $(NF-3)}' | xargs -r kill -9
      idle=0; still=0
    fi
  done
  wait $pid
}
xpy() {  # xpy <log> <x.py args...>
  local log=$1; shift
  local try bad tree
  for try in 1 2 3 4 5 6; do
    run_watched $log.$try "$@" && { cp $log.$try $log; return 0; }
    cp $log.$try $log
    [ -e $log.$try.hung ] && { echo "RETRY $try: after hang $(date +%T)" >> $S; continue; }
    grep -qE "$CORRUPT_RE" $log || { echo "BUILD ERROR (not corruption) see $log" >> $S; return 1; }
    bad=$(grep -E "$CORRUPT_RE" $log | grep -oE "/[^ :()'\"]+\.(rlib|rmeta|o)" | sort -u)
    tree=$(grep -A4 -E '^error: could not compile' $log | grep -oE -- '--out-dir [^ ]*build/x86_64-unknown-haiku/[A-Za-z0-9_-]+' | grep -oE 'build/x86_64-unknown-haiku/[A-Za-z0-9_-]+' | head -1)
    echo "RETRY $try: corruption; named=[$(echo $bad)] tree=[$tree] $(date +%T)" >> $S
    mkdir -p ~/rust/corrupt-evidence; grep -E "$CORRUPT_RE" $log | head -3 | cut -c1-300 >> ~/rust/corrupt-evidence/signatures.txt
    # Metadata ICEs name no file, but the query stack names the crate being decoded.
    if [ -z "$bad" ]; then
      local crates=$(grep -E '^#[0-9]+ \[' $log | grep -oE '`[a-z_][a-z0-9_]*::' | tr -d '`:' | sort -u | grep -vxE 'core|alloc|std|rustc_[a-z_]+')
      local dd=$(grep -oE '/[^ ]*/build/x86_64-unknown-haiku/[A-Za-z0-9_-]+/x86_64-unknown-haiku/release' $log | head -1)
      for c in $crates; do bad="$bad $(ls -d $dd/deps/lib$c-*.rlib $dd/deps/lib$c-*.rmeta $dd/build/$c/*/out/lib$c-*.r* 2>/dev/null)"; done
      bad=$(echo $bad)
      [ -n "$bad" ] && echo "  ICE crates=[$(echo $crates)]" >> $S
    fi
    if [ -n "$bad" ]; then
      for b in $bad; do [ -f "$b" ] && cp "$b" ~/rust/corrupt-evidence/ 2>/dev/null; rm -f "${b%.*}".rlib "${b%.*}".rmeta "$b"; n=$(basename "${b%.*}"); n=${n#lib}; rm -rf $(dirname "$b")/../.fingerprint/$n; done
    elif [ -n "$tree" ]; then
      rm -rf "$tree"
    else
      # Nothing named: retry as is (the bad read may have been transient). Never
      # wipe every stage tree blindly; that throws away hours of good output.
      :
    fi
  done
  return 1
}
