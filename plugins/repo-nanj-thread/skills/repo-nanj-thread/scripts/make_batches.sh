#!/usr/bin/env bash
# make_batches.sh — 工程1: 読了バッチの作成
# 使い方: bash make_batches.sh <OUT> [最大バイト/バッチ=122880] [最大ファイル数/バッチ=20]
# 既定値の役割: 122880 バイト（120KiB）は1バッチに入れるファイルの合計サイズの上限、20 は1バッチに入れるファイル数の上限。根拠は未記録（経験値）。SKILL.md 工程2 の同時実行数（20・Claude Code の既定値）とは無関係。変更は実測で判断する。
# inventory.tsv をパス順のまま、累積バイト数とファイル数でバッチに分割する。
# 出力: $OUT/batches/NN.tsv（inventory.tsv と同じ列）。標準出力にバッチ数。
set -euo pipefail
OUT="${1:?usage: make_batches.sh OUT [max_bytes] [max_files]}"
MAXB="${2:-122880}"
MAXF="${3:-20}"

rm -f "$OUT"/batches/[0-9][0-9].tsv "$OUT"/batches/[0-9][0-9][0-9].tsv
awk -F'\t' -v OUT="$OUT" -v MAXB="$MAXB" -v MAXF="$MAXF" '
  BEGIN{ n=1; b=0; c=0 }
  {
    if (c>0 && (b+$2>MAXB || c>=MAXF)) { n++; b=0; c=0 }
    file=sprintf("%s/batches/%02d.tsv", OUT, n)
    print $0 >> file
    b+=$2; c++
  }
  END{ print n }
' "$OUT/inventory.tsv"
