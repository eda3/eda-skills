#!/usr/bin/env bash
# assemble.sh — 工程5: 最終HTMLの組み立て
# 使い方: bash assemble.sh <OUT> <SKILL_DIR>
# assets/template.html の {{KEY}} を summary.txt・plan・実測レス数で置換し、
# <!-- TOC --> に blocks.tsv から作った目次、<!-- PARTS --> に parts/*.html を挿入する。
# 数値はすべて計測値を使う。標準出力の最終行 = 最終HTMLの絶対パス。
set -euo pipefail
OUT="${1:?usage: assemble.sh OUT SKILL_DIR}"
SKILL_DIR="${2:?usage: assemble.sh OUT SKILL_DIR}"
TPL="$SKILL_DIR/assets/template.html"
HTML="$OUT/$(basename "$OUT").html"

sval() { { grep -m1 "^$1=" "$OUT/summary.txt" || true; } | sed "s/^$1=//" | tr -d '\r'; }

TITLE=$({ grep -m1 '^title:' "$OUT/plan/plan.md" || true; } | sed 's/^title:[[:space:]]*//' | tr -d '\r')
[ -n "$TITLE" ] || { echo "ERROR: plan.md に title: 行がない" >&2; exit 1; }
REPO=$(sval repo); FILES=$(sval total_files); LINES=$(sval total_lines)
EXCL=$(sval excluded); COMMIT=$(sval last_commit); LIC=$(sval license_file)
DATE=$(date '+%Y-%m-%d %H:%M')
BLOCKS=$(wc -l < "$OUT/plan/blocks.tsv" | tr -d ' ')

cat "$OUT"/parts/*.html > "$OUT/.parts.html"
CR=$(bash "$SKILL_DIR/scripts/count_res.sh" "$OUT/.parts.html" || true)
RES=$(printf '%s\n' "$CR" | head -1 | sed 's/^count=\([0-9]*\).*/\1/')

TOC=$(tr -d '\r' < "$OUT/plan/blocks.tsv" | awk -F'\t' \
  '{printf "<li><a href=\"#r%s\">%s</a><span class=\"range\">&gt;&gt;%s-%s</span></li>\n", $2, $4, $2, $3}')

{
  while IFS= read -r line; do
    case "$line" in
      *'<!-- TOC -->'*)   printf '%s\n' "$TOC" ;;
      *'<!-- PARTS -->'*) cat "$OUT/.parts.html" ;;
      *)
        line=${line//'{{TITLE}}'/$TITLE}
        line=${line//'{{REPO}}'/$REPO}
        line=${line//'{{FILES}}'/$FILES}
        line=${line//'{{LINES}}'/$LINES}
        line=${line//'{{EXCL}}'/$EXCL}
        line=${line//'{{RES}}'/$RES}
        line=${line//'{{BLOCKS}}'/$BLOCKS}
        line=${line//'{{COMMIT}}'/$COMMIT}
        line=${line//'{{LICENSE}}'/$LIC}
        line=${line//'{{DATE}}'/$DATE}
        printf '%s\n' "$line" ;;
    esac
  done < "$TPL"
} > "$HTML"

echo "res=$RES blocks=$BLOCKS"
echo "$HTML"
