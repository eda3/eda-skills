#!/usr/bin/env bash
# check_plan.sh — 工程3: 構成計画の機械照合
# 使い方: bash check_plan.sh <OUT> [レス下限=900] [レス上限=1000]
# 照合対象:
#   plan/blocks.tsv  block <TAB> start <TAB> end <TAB> theme（ヘッダ行なし）
#   plan/assign.tsv  path <TAB> block <TAB> mode(file|dir)
#   plan/plan.md     先頭付近に "title: <スレタイ>" の行
# FAIL 条件: レス番号が1から連続でない／総レス数が範囲外／inventory に未割り当てのパスがある／title 行がない
set -euo pipefail
OUT="${1:?usage: check_plan.sh OUT}"
LO="${2:-900}"; HI="${3:-1000}"
B="$OUT/plan/blocks.tsv"; A="$OUT/plan/assign.tsv"; P="$OUT/plan/plan.md"
FAIL=0

for f in "$B" "$A" "$P"; do
  [ -f "$f" ] || { echo "[FAIL] ファイルがない: $f"; FAIL=1; }
done
[ "$FAIL" -eq 1 ] && { echo "RESULT FAIL"; exit 1; }

if grep -q '^title:' "$P"; then
  echo "[PASS] title: $(grep -m1 '^title:' "$P" | sed 's/^title:[[:space:]]*//')"
else
  echo "[FAIL] plan.md に 'title: <スレタイ>' の行がない"; FAIL=1
fi

# ブロックの連続性と総レス数
tr -d '\r' < "$B" | awk -F'\t' -v LO="$LO" -v HI="$HI" '
  NF<4 { printf "[FAIL] blocks.tsv %d行目: 列が4未満\n", NR; bad=1; next }
  {
    if ($2+0 != $2 || $3+0 != $3) { printf "[FAIL] blocks.tsv %d行目: start/end が数値でない\n", NR; bad=1; next }
    if (NR==1 && $2!=1) { printf "[FAIL] 先頭ブロックの start が 1 でない (=%d)\n", $2; bad=1 }
    if (NR>1 && $2 != prev_end+1) { printf "[FAIL] ブロック %s: start=%d が前ブロック end=%d+1 と不連続\n", $1, $2, prev_end; bad=1 }
    size=$3-$2+1
    if (size<70 || size>130) { printf "[WARN] ブロック %s: サイズ %d（推奨 70〜130）\n", $1, size }
    printf "[INFO] ブロック %s: %d〜%d (%dレス) %s\n", $1, $2, $3, size, $4
    prev_end=$3; nblocks=NR; total=$3
  }
  END{
    if (nblocks<8 || nblocks>12) printf "[WARN] ブロック数 %d（推奨 8〜12）\n", nblocks
    if (total<LO || total>HI) { printf "[FAIL] 総レス数 %d（許容 %d〜%d）\n", total, LO, HI; bad=1 }
    else printf "[PASS] 総レス数 %d（許容 %d〜%d）\n", total, LO, HI
    exit bad?1:0
  }
' || FAIL=1

# assign の block 参照が実在するか
cut -f1 "$B" | tr -d '\r' | sort -u > "$OUT/.blk_ids.txt"
tr -d '\r' < "$A" | awk -F'\t' 'NF>=2{print $2}' | sort -u > "$OUT/.blk_refs.txt"
if BADREF=$(comm -13 "$OUT/.blk_ids.txt" "$OUT/.blk_refs.txt"); [ -n "$BADREF" ]; then
  echo "[FAIL] assign.tsv が存在しないブロックを参照: $(echo "$BADREF" | paste -sd, -)"; FAIL=1
fi

# 全ファイルの割り当て（file 行の完全一致、または dir 行のプレフィックス一致）
tr -d '\r' < "$A" | awk -F'\t' '$3=="dir"{print $1}'  | sort -u > "$OUT/.dir_rows.txt"
tr -d '\r' < "$A" | awk -F'\t' '$3!="dir"{print $1}'  | sort -u > "$OUT/.file_rows.txt"
cut -f1 "$OUT/inventory.tsv" | tr -d '\r' | sort -u > "$OUT/.inv_paths.txt"

UNCOV=$(awk -F'\t' '
  FILENAME ~ /\.file_rows\.txt$/ { frow[$0]=1; next }
  FILENAME ~ /\.dir_rows\.txt$/  { drow[$0]=1; nd++; dirs[nd]=$0; next }
  {
    p=$0
    if (p in frow) next
    hit=0
    for (i=1;i<=nd;i++) { d=dirs[i]; sub(/\/$/,"",d); if (index(p, d "/")==1) { hit=1; break } }
    if (!hit) print p
  }
' "$OUT/.file_rows.txt" "$OUT/.dir_rows.txt" "$OUT/.inv_paths.txt")
if [ -n "$UNCOV" ]; then
  NUN=$(printf '%s\n' "$UNCOV" | wc -l | tr -d ' ')
  echo "[FAIL] 未割り当てのファイル $NUN 件（先頭10件）:"; printf '%s\n' "$UNCOV" | awk 'NR<=10'
  FAIL=1
else
  echo "[PASS] inventory の全パスがブロックに割り当て済み"
fi

# assign にあるが inventory にないパス（誤記の検出）
if GHOST=$(comm -13 "$OUT/.inv_paths.txt" "$OUT/.file_rows.txt"); [ -n "$GHOST" ]; then
  echo "[WARN] inventory に存在しない file 行（誤記の可能性）: $(echo "$GHOST" | awk 'NR<=5' | paste -sd, -)"
fi

if [ "$FAIL" -eq 0 ]; then echo "RESULT PASS"; else echo "RESULT FAIL"; exit 1; fi
