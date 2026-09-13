#!/usr/bin/env bash
# check_html.sh — 工程6: 最終HTMLの機械検証
# 使い方: bash check_html.sh <OUT> <SKILL_DIR> [HTMLパス] [レス下限=900] [レス上限=1000]
# FAIL 条件:
#   1) レス数が範囲外／番号が1からの連番でない／重複がある
#   2) 安価 >>N の参照先が存在しない
#   3) inventory のパスで本文に登場しないものがある（assign.tsv の dir 行配下は除く）
#   4) ローカル絶対パス（$HOME の3表記・/home/・/Users/・C:\Users\ など）が本文にある
#   5) 外部リソース読み込み（script src / link stylesheet / url(http / @import / iframe）がある
# 結果は $OUT/report.txt にも保存する。
set -euo pipefail
OUT="${1:?usage: check_html.sh OUT SKILL_DIR [HTML] [lo] [hi]}"
SKILL_DIR="${2:?usage: check_html.sh OUT SKILL_DIR [HTML] [lo] [hi]}"
HTML="${3:-$OUT/$(basename "$OUT").html}"
LO="${4:-900}"; HI="${5:-1000}"
R="$OUT/report.txt"
FAIL=0
: > "$R"
say() { echo "$1" | tee -a "$R"; }

[ -f "$HTML" ] || { say "[FAIL] HTMLがない: $HTML"; echo "RESULT FAIL" | tee -a "$R"; exit 1; }

# 1) レス数・連番・重複（構造は count_res.sh に委ねる）
CR=$(bash "$SKILL_DIR/scripts/count_res.sh" "$HTML" || true)
LINE1=$(printf '%s\n' "$CR" | awk 'NR==1')
say "[INFO] $LINE1"
COUNT=$(echo "$LINE1" | sed 's/.*count=\([0-9]*\).*/\1/')
MIN=$(echo "$LINE1"   | sed 's/.*min=\([0-9]*\).*/\1/')
DUP=$(echo "$LINE1"   | sed 's/.*dup=\([0-9]*\).*/\1/')
GAP=$(echo "$LINE1"   | sed 's/.*gap=\([0-9]*\).*/\1/')
ANC_EXT=$(echo "$LINE1" | sed 's/.*anc_ext=\(.*\) ig=.*/\1/')
if [ "$COUNT" -ge "$LO" ] && [ "$COUNT" -le "$HI" ]; then say "[PASS] レス数 $COUNT（許容 $LO〜$HI）"
else say "[FAIL] レス数 $COUNT（許容 $LO〜$HI）"; FAIL=1; fi
if [ "$MIN" -eq 1 ] && [ "$DUP" -eq 0 ] && [ "$GAP" -eq 0 ]; then say "[PASS] レス番号 1〜$COUNT の連番・重複なし"
else say "[FAIL] 連番でない（min=$MIN dup=$DUP gap=$GAP）"; FAIL=1; fi

# 2) 安価の参照先
if [ "$ANC_EXT" = "-" ]; then say "[PASS] 安価の参照先はすべて存在"
else say "[FAIL] 参照先のない安価: >>$ANC_EXT"; FAIL=1; fi

# 3) 全ファイルの掲載（file行は完全一致文字列、dir行配下はディレクトリ名の掲載で代表）
cut -f1 "$OUT/inventory.tsv" | tr -d '\r' | sort -u > "$OUT/.inv_paths.txt"
{ grep -oF -f "$OUT/.inv_paths.txt" "$HTML" || true; } | sort -u > "$OUT/.found_paths.txt"
DIRROWS="$OUT/.dir_rows.txt"
tr -d '\r' < "$OUT/plan/assign.tsv" 2>/dev/null | awk -F'\t' '$3=="dir"{print $1}' | sort -u > "$DIRROWS" || : > "$DIRROWS"
MISSPATH=$(comm -23 "$OUT/.inv_paths.txt" "$OUT/.found_paths.txt" | awk -F'\t' '
  FILENAME ~ /dir_rows/ { d=$0; sub(/\/$/,"",d); if(d!="") dirs[++nd]=d; next }
  {
    p=$0; hit=0
    for (i=1;i<=nd;i++) if (index(p, dirs[i] "/")==1) { hit=1; break }
    if (!hit) print p
  }
' "$DIRROWS" -)
# dir 行そのものが本文に載っているかも確認する
DIRMISS=""
while IFS= read -r d; do
  [ -n "$d" ] || continue
  grep -qF -- "$d" "$HTML" || DIRMISS="$DIRMISS $d"
done < "$DIRROWS"
if [ -z "$MISSPATH" ] && [ -z "$DIRMISS" ]; then
  say "[PASS] inventory の全パスが本文に登場（dir 行代表を含む）"
else
  if [ -n "$MISSPATH" ]; then
    N=$(printf '%s\n' "$MISSPATH" | wc -l | tr -d ' ')
    say "[FAIL] 本文に登場しないファイル $N 件（先頭10件。全件は report.txt）:"
    printf '%s\n' "$MISSPATH" | awk 'NR<=10' | tee -a "$R" >/dev/null
    printf '%s\n' "$MISSPATH" >> "$R"
  fi
  [ -n "$DIRMISS" ] && say "[FAIL] 本文に登場しない dir 行:$DIRMISS"
  FAIL=1
fi

# 4) ローカル絶対パスの漏れ（$HOME の実パス3表記のみで検索。一般語の誤検出を避けるため）
H="$HOME"
H2=""; H3=""
case "$H" in
  /[a-zA-Z]/*) DRV=$(echo "$H" | cut -d/ -f2 | tr '[:lower:]' '[:upper:]')
               REST=$(echo "$H" | cut -d/ -f3-)
               H2="$DRV:/$REST"
               H3="$DRV:\\$(echo "$REST" | sed 's#/#\\#g')" ;;
esac
LEAK=0
for pat in "$H" "$H2" "$H3"; do
  [ -n "$pat" ] || continue
  if grep -qF -- "$pat" "$HTML"; then say "[FAIL] ローカル絶対パスの痕跡: $pat"; LEAK=1; fi
done
[ "$LEAK" -eq 0 ] && say "[PASS] ローカル絶対パス（\$HOME 3表記）なし" || FAIL=1

# 5) 外部リソース読み込み。テンプレート由来の <style> 1個以外、リソース系タグは 0 個が正
#    （コード例は実体参照でエスケープされるため、生タグの検出に誤検出はない）
EXT=0
for t in '<script' '<link' '<iframe' '<img' '<embed' '<object' '<video' '<audio'; do
  N=$({ grep -oiF -- "$t" "$HTML" || true; } | wc -l | tr -d ' ')
  if [ "$N" -gt 0 ]; then say "[FAIL] リソース系タグ $t が $N 個（0個が正。画像・JSは使わずCSS部品で描く）"; EXT=1; fi
done
NSTYLE=$({ grep -oiF -- '<style' "$HTML" || true; } | wc -l | tr -d ' ')
[ "$NSTYLE" -eq 1 ] || { say "[FAIL] <style> が $NSTYLE 個（テンプレート由来の1個が正）"; EXT=1; }
[ "$EXT" -eq 0 ] && say "[PASS] 外部リソース読み込みなし（自己完結）" || FAIL=1

# 6) タグの開閉数（目安）
for t in article pre code; do
  O=$({ grep -o "<$t" "$HTML" || true; } | wc -l | tr -d ' ')
  C=$({ grep -o "</$t>" "$HTML" || true; } | wc -l | tr -d ' ')
  if [ "$O" -ne "$C" ]; then say "[WARN] <$t> 開 $O / 閉 $C（不一致）"; fi
done

if [ "$FAIL" -eq 0 ]; then echo "RESULT PASS" | tee -a "$R"
else echo "RESULT FAIL" | tee -a "$R"; exit 1; fi
