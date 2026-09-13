#!/usr/bin/env bash
# inventory.sh — 工程1: リポジトリの棚卸し
# 前提: カレントディレクトリがリポジトリのルート
# 使い方: bash inventory.sh
# 出力: $OUT/inventory.tsv  (path <TAB> bytes <TAB> lines <TAB> ext <TAB> large)
#       $OUT/excluded.txt   (path <TAB> 除外理由)
#       $OUT/summary.txt    (key=value)
#       標準出力の最終行 = OUT の絶対パス（以降の全工程でこの値を使い回す）
# 除外の判断はこのスクリプトが行う。
set -euo pipefail

ROOT="$(pwd -P)"
REPO="$(basename "$ROOT")"
TS="$(date +%Y%m%d_%H%M)"
BASE="${NANJ_OUT:-$HOME/nanj-threads}"
OUT="$BASE/${REPO}_nanj_${TS}"
mkdir -p "$OUT/batches" "$OUT/read" "$OUT/plan" "$OUT/parts"

LARGE_BYTES=204800   # これを超えるファイルは large=1（部分読解の対象）

EXCL_DIR='(^|/)(\.git|\.hg|\.svn|node_modules|target|dist|build|out|vendor|third_party|\.venv|venv|__pycache__|\.next|\.nuxt|\.svelte-kit|coverage|\.cache|\.idea|\.vscode|\.claude)(/|$)'
EXCL_LOCK='(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lockb|Cargo\.lock|poetry\.lock|uv\.lock|Pipfile\.lock|go\.sum|composer\.lock|Gemfile\.lock|flake\.lock|\.DS_Store|Thumbs\.db)$'
EXCL_SECRET='(^|/)(\.env(\..*)?|.*\.(pem|key|pfx|p12)|id_rsa.*|id_ed25519.*|.*credentials.*\.json)$'
OK_ENV='(^|/)\.env\.(example|sample|template|dist)$'
BIN_EXT='\.(png|jpe?g|gif|bmp|ico|webp|avif|tiff?|pdf|zip|gz|tgz|bz2|xz|7z|rar|jar|war|class|exe|dll|so|dylib|o|a|lib|bin|dat|db|sqlite3?|parquet|woff2?|ttf|otf|eot|mp3|mp4|m4a|wav|ogg|mov|webm|pyc|pyo|wasm|onnx|pt|pth|gguf|npy|npz)$'

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then VCS=git; else VCS=none; fi
if [ "$VCS" = git ]; then
  git -c core.quotepath=false ls-files --cached --others --exclude-standard
else
  find . -type f | sed 's#^\./##'
fi | tr -d '\r' | sort > "$OUT/.all.txt"

: > "$OUT/inventory.tsv"
: > "$OUT/excluded.txt"

while IFS= read -r f; do
  [ -f "$f" ] || continue
  if printf '%s\n' "$f" | grep -Eq "$EXCL_DIR";  then printf '%s\t%s\n' "$f" "dir-excluded"  >> "$OUT/excluded.txt"; continue; fi
  if printf '%s\n' "$f" | grep -Eq "$EXCL_LOCK"; then printf '%s\t%s\n' "$f" "lockfile"      >> "$OUT/excluded.txt"; continue; fi
  if printf '%s\n' "$f" | grep -Eq "$EXCL_SECRET" && ! printf '%s\n' "$f" | grep -Eq "$OK_ENV"; then
    printf '%s\t%s\n' "$f" "secret(存在のみ記載可・内容は読まない)" >> "$OUT/excluded.txt"; continue
  fi
  if printf '%s\n' "$f" | grep -Eiq "$BIN_EXT";  then printf '%s\t%s\n' "$f" "binary-ext"    >> "$OUT/excluded.txt"; continue; fi
  if [ -s "$f" ] && ! grep -Iq . "$f" 2>/dev/null; then
    printf '%s\t%s\n' "$f" "binary-content" >> "$OUT/excluded.txt"; continue
  fi
  bytes=$(wc -c < "$f" | tr -d ' ')
  lines=$(wc -l < "$f" | tr -d ' ')
  base="${f##*/}"
  case "$base" in
    *.*) ext="${base##*.}" ;;
    *)   ext="(none)" ;;
  esac
  large=0; [ "$bytes" -gt "$LARGE_BYTES" ] && large=1
  printf '%s\t%s\t%s\t%s\t%s\n' "$f" "$bytes" "$lines" "$ext" "$large" >> "$OUT/inventory.tsv"
done < "$OUT/.all.txt"

TOTAL=$(wc -l < "$OUT/inventory.tsv" | tr -d ' ')
EXCL=$(wc -l < "$OUT/excluded.txt" | tr -d ' ')
TLINES=$(awk -F'\t' '{s+=$3} END{print s+0}' "$OUT/inventory.tsv")
TBYTES=$(awk -F'\t' '{s+=$2} END{print s+0}' "$OUT/inventory.tsv")
NLARGE=$(awk -F'\t' '$5==1' "$OUT/inventory.tsv" | wc -l | tr -d ' ')
TOPEXT=$(awk -F'\t' '{c[$4]++} END{for(e in c) printf "%s:%d\n", e, c[e]}' "$OUT/inventory.tsv" \
         | sort -t: -k2,2nr | awk 'NR<=8' | paste -sd, -)

# README の1行目（バッジ・HTMLタグ行は読み飛ばす。主語の取り違えを防ぐため原文で保持する）
README=$(ls 2>/dev/null | grep -i -m1 '^readme' || true)
RFIRST="-"
if [ -n "$README" ] && [ -f "$README" ]; then
  RFIRST=$(tr -d '\r' < "$README" | sed -e 's/^#\+[[:space:]]*//' \
           | grep -v -E '^[[:space:]]*$|^<|^\[!\[|^!\[|^-{3,}$|^={3,}$' | head -1 || true)
  [ -n "$RFIRST" ] || RFIRST="-"
fi
# README の説明文（見出し・バッジ・HTML行を除いた最初の本文行。OPの引用に使う）
RDESC="-"
if [ -n "$README" ] && [ -f "$README" ]; then
  RDESC=$(tr -d '\r' < "$README" \
          | grep -v -E '^[[:space:]]*$|^#|^<|^\[!\[|^!\[|^-{3,}$|^={3,}$|^\|' | head -1 || true)
  [ -n "$RDESC" ] || RDESC="-"
fi
LICF=$(ls 2>/dev/null | grep -i -m1 -E '^(license|licence|copying)' || true)
LFIRST="-"
if [ -n "$LICF" ] && [ -f "$LICF" ]; then
  LFIRST=$(tr -d '\r' < "$LICF" | grep -v -E '^[[:space:]]*$' | head -1 || true)
  [ -n "$LFIRST" ] || LFIRST="-"
fi
LASTC="-"
[ "$VCS" = git ] && LASTC=$(git log -1 --format=%cs 2>/dev/null || echo "-")

{
  echo "repo=$REPO"
  echo "vcs=$VCS"
  echo "total_files=$TOTAL"
  echo "total_lines=$TLINES"
  echo "total_bytes=$TBYTES"
  echo "excluded=$EXCL"
  echo "large=$NLARGE"
  echo "top_ext=$TOPEXT"
  echo "readme=${README:--}"
  echo "readme_first_line=$RFIRST"
  echo "readme_desc=$RDESC"
  echo "license_file=${LICF:--}"
  echo "license_first_line=$LFIRST"
  echo "last_commit=$LASTC"
  echo "generated=$(date '+%Y-%m-%d %H:%M')"
} > "$OUT/summary.txt"

if [ "$TOTAL" -eq 0 ]; then
  echo "ERROR: 対象ファイルが 0 件（excluded=$EXCL）。" >&2
  echo "$OUT"
  exit 2
fi

cat "$OUT/summary.txt"
echo "$OUT"
