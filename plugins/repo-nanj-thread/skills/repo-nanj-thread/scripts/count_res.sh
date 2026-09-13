#!/usr/bin/env bash
# count_res.sh — レス数の計測と番号・配分の照合
# 使い方:
#   bash count_res.sh <HTMLファイル>                → 構造チェック（連番・重複）のみ判定。配分は WARN
#   bash count_res.sh <HTMLファイル> <START> <END>  → 執筆者の自己チェック用。範囲一致と配分も NG 判定
# レスの定義: <article class="res" data-n="N"> 1個 = 1レス。番号は data-n の値で数える。
# 出力1行目: count= min= max= dup= gap= anc_ext=<範囲外安価の番号列> ig= short_pct= ids:<ID=件数,...>
# 最終行: RESULT OK ／ RESULT NG: <理由>
set -euo pipefail
F="${1:?usage: count_res.sh FILE [START END]}"
START="${2:-}"; END="${3:-}"
export LC_ALL=C   # length() をバイト数で数える（短レス判定 45バイト ≒ 日本語15文字）

NUMS=$(grep -o 'data-n="[0-9]*"' "$F" | grep -o '[0-9]*' || true)
STATS=$(printf '%s\n' "$NUMS" | awk '
  NF { c++; if (mn=="" || $1<mn) mn=$1; if (mx=="" || $1>mx) mx=$1; if (seen[$1]++) dup++ }
  END { printf "%d %d %d %d", c+0, mn+0, mx+0, dup+0 }')
read -r COUNT MIN MAX DUP <<<"$STATS"
if [ "$COUNT" -eq 0 ]; then echo "count=0"; echo "RESULT NG: レスが1件もない"; exit 1; fi
EXPECT=$((MAX - MIN + 1))
GAP=$((EXPECT - COUNT + DUP))   # DUP は重複の「余分な出現数」。連番なら GAP=0 になる

ANC=$(grep -o 'href="#r[0-9]*"' "$F" | grep -o '[0-9]*' | sort -n | uniq || true)
ANC_EXT=$(printf '%s\n' "$ANC" | awk -v lo="$MIN" -v hi="$MAX" 'NF && ($1<lo || $1>hi)' | paste -sd' ' -)
[ -n "$ANC_EXT" ] || ANC_EXT="-"

IG=$(grep -o 'class="ig ' "$F" | wc -l | tr -d ' ')
IDS=$({ grep -o 'ID:[A-Za-z0-9]\{4,12\}' "$F" || true; } | sort | uniq -c | sort -rn \
      | awk 'NR<=6{printf "%s=%s,", substr($2,4), $1}' | sed 's/,$//')
[ -n "$IDS" ] || IDS="-"

read -r SHORT_PCT SHOSIN_PCT <<EOF2
$(awk -v total="$COUNT" '
  /<article/ { inart=1; buf="" }
  inart      { buf = buf " " $0 }
  /<\/article>/ && inart {
    inart=0
    body=buf
    sub(/<header[^>]*>.*<\/header>/, " ", body)
    gsub(/<[^>]*>/, "", body)
    gsub(/&[a-zA-Z]+;|&#[0-9]+;/, "xx", body)
    gsub(/[[:space:]]/, "", body)
    if (length(body) < 45) short++
    if (buf ~ /ID:SyoSinsy/) shosin++
  }
  END{
    if (total==0) total=1
    printf "%d %d\n", int(short*100/total), int(shosin*100/total)
  }
' "$F")
EOF2

echo "count=$COUNT min=$MIN max=$MAX dup=$DUP gap=$GAP anc_ext=$ANC_EXT ig=$IG short_pct=$SHORT_PCT shosin_pct=$SHOSIN_PCT ids:$IDS"

NG=""
[ "$DUP" -gt 0 ] && NG="$NG 番号の重複${DUP}件;"
[ "$GAP" -gt 0 ] && NG="$NG 欠番${GAP}件;"
if [ -n "$START" ] && [ -n "$END" ]; then
  [ "$MIN" -eq "$START" ] || NG="$NG min=$MIN が start=$START と不一致;"
  [ "$MAX" -eq "$END" ]   || NG="$NG max=$MAX が end=$END と不一致;"
  WANT=$((END - START + 1))
  [ "$COUNT" -eq "$WANT" ] || NG="$NG count=$COUNT が ${WANT} と不一致;"
  [ "$IG" -ge 3 ]          || NG="$NG インフォグラフィック${IG}個（3個以上にする）;"
  [ "$SHORT_PCT" -le 25 ]  || NG="$NG 1行レス${SHORT_PCT}%（25%以下にする）;"
  [ "$SHOSIN_PCT" -ge 15 ] || NG="$NG 初心者ニキ${SHOSIN_PCT}%（15%以上にする）;"
else
  [ "$IG" -ge 3 ]          || echo "[WARN] インフォグラフィック ${IG}個"
  [ "$SHORT_PCT" -le 25 ]  || echo "[WARN] 1行レス ${SHORT_PCT}%"
  [ "$SHOSIN_PCT" -ge 15 ] || echo "[WARN] 初心者ニキ ${SHOSIN_PCT}%"
fi

if [ -z "$NG" ]; then echo "RESULT OK"; else echo "RESULT NG:$NG"; exit 1; fi
