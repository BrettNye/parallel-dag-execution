#!/usr/bin/env bash
# Tests for make-blind.sh in a throwaway git repo.
HERE="$(cd "$(dirname "$0")/.." && pwd)"
fails=0; passes=0
ok()   { passes=$((passes+1)); echo "  PASS: $1"; }
bad()  { fails=$((fails+1));  echo "  FAIL: $1"; }
chk()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected [$3] got [$2])"; fi; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
R="$tmp/repo"; D="$tmp/rev parent"; mkdir -p "$R/experiments" "$D"
export D2_RUNS="$tmp/runs"
g() { git -C "$R" -c user.name=t -c user.email=t@t "$@"; }
echo x > "$R/experiments/x.txt"; echo y > "$R/y.txt"
g init -q && g add experiments/x.txt y.txt && g commit -qm base
for b in d2/none-1 d2/round1-1 d2/full-1; do g branch "$b"; g checkout -q "$b"; echo "$b" > "$R/y.txt"; g commit -qam "$b"; done
g checkout -q -

echo "T1: three branches get three letters, worktrees and a key"
out="$(bash "$HERE/make-blind.sh" "$R" "$D" d2/none-1 d2/round1-1 d2/full-1 2>&1)"; rc=$?
chk "exit 0 with a space in dest" "$rc" "0"
key="$tmp/runs/blind-key.txt"
chk "key has three lines" "$(wc -l < "$key" | tr -d ' ')" "3"
chk "letters are P, Q, R" "$(cut -d= -f1 "$key" | tr '\n' ' ')" "P Q R "
chk "branches are a permutation" "$(cut -d= -f2 "$key" | cut -d' ' -f1 | sort | tr '\n' ' ')" "d2/full-1 d2/none-1 d2/round1-1 "
while IFS= read -r line; do
  L=${line%%=*}; rest=${line#*=}; br=${rest%% *}; sha=${rest#* }
  chk "review-$L at $br head" "$(git -C "$D/review-$L" rev-parse HEAD)" "$(g rev-parse "$br")"
  chk "key sha for $L" "$sha" "$(g rev-parse "$br")"
  [ -e "$D/review-$L/experiments" ]; chk "review-$L has no experiments/" "$?" "1"
done < "$key"

echo
echo "T2: refusals"
bash "$HERE/make-blind.sh" "$R" "$D" d2/none-1 >/dev/null 2>&1; chk "existing key exits 2" "$?" "2"
rm -f "$key"
bash "$HERE/make-blind.sh" "$R" "$tmp/other" d2/nope >/dev/null 2>&1; chk "unknown branch exits 2" "$?" "2"
mkdir -p "$tmp/other"
bash "$HERE/make-blind.sh" "$R" "$tmp/other" a b c d e f g >/dev/null 2>&1; chk "seven branches exit 2" "$?" "2"
bash "$HERE/make-blind.sh" "$R" "$D" d2/none-1 >/dev/null 2>&1; chk "existing review-P exits 2" "$?" "2"
bash "$HERE/make-blind.sh" "$R" >/dev/null 2>&1; chk "no branches exits 2" "$?" "2"

for w in "$D"/review-*; do g worktree remove --force "$w" >/dev/null 2>&1; done
echo "RESULT: $passes passed, $fails failed"
[ "$fails" -eq 0 ]
