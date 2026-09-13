#!/usr/bin/env bash
# check_read.sh — 工程2: 読了記録の全件照合
# 使い方: bash check_read.sh <OUT>
# inventory.tsv の全パスに read/*.jsonl の記録（"path":"..."）があるかを機械照合する。
# 欠けたパスは $OUT/batches/retry.tsv（inventory と同じ列）に書き出す。
# 出力例: READ_OK full=42 partial=3 unreadable=1  ／ READ_MISSING 5
# 制限: パスに二重引用符を含むファイルは照合できない（現実のリポジトリではまず出ない）。
set -euo pipefail
OUT="${1:?usage: check_read.sh OUT}"

ALL="$OUT/.read_paths.txt"
if ls "$OUT"/read/*.jsonl >/dev/null 2>&1; then
  cat "$OUT"/read/*.jsonl | tr -d '\r' | sed 's/"path"[[:space:]]*:[[:space:]]*"/"path":"/g' \
    | grep -o '"path":"[^"]*"' | sed 's/^"path":"//; s/"$//' | sort -u > "$ALL"
else
  : > "$ALL"
fi

cut -f1 "$OUT/inventory.tsv" | tr -d '\r' | sort -u > "$OUT/.inv_paths.txt"
comm -23 "$OUT/.inv_paths.txt" "$ALL" > "$OUT/.missing.txt"
MISS=$(wc -l < "$OUT/.missing.txt" | tr -d ' ')

: > "$OUT/batches/retry.tsv"
if [ "$MISS" -gt 0 ]; then
  grep -F -f "$OUT/.missing.txt" "$OUT/inventory.tsv" | awk -F'\t' 'NR==FNR{m[$1]=1;next} m[$1]' "$OUT/.missing.txt" - \
    > "$OUT/batches/retry.tsv" || true
fi

count_status() {
  { cat "$OUT"/read/*.jsonl 2>/dev/null || true; } \
    | { grep -o "\"status\"[[:space:]]*:[[:space:]]*\"$1\"" || true; } | wc -l | tr -d ' '
}
FULL=$(count_status full)
PART=$(count_status partial)
UNRD=$(count_status unreadable)

if [ "$MISS" -eq 0 ]; then
  echo "READ_OK full=$FULL partial=$PART unreadable=$UNRD"
else
  echo "READ_MISSING $MISS full=$FULL partial=$PART unreadable=$UNRD"
  echo "未読了のパス（先頭20件。全件は $OUT/batches/retry.tsv）:"
  head -20 "$OUT/.missing.txt"
  exit 1
fi
