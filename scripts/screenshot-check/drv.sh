#!/bin/zsh
# usage: drv.sh "cmd1" "cmd2" ...   (LOCAL VERIFY ONLY)
D=${KL_DRV:-$HOME/kl-verify/drv}
n=$(date +%s%N 2>/dev/null || date +%s)$RANDOM
{ echo "#$n"; for c in "$@"; do echo "$c"; done; } > $D/cmd.tmp && mv $D/cmd.tmp $D/cmd.txt
for i in $(seq 1 600); do
  if head -1 $D/resp.txt 2>/dev/null | grep -q "#$n"; then tail -n +2 $D/resp.txt; exit 0; fi
  sleep 0.5
done
echo "TIMEOUT"; exit 1
