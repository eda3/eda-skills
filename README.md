# eda-skills

Claude Code用のスキルを配布するマーケットプレイスリポジトリ。

## 収録スキル

### repo-nanj-thread

今いるリポジトリの全ファイルをサブエージェントで読み切り、初心者向けの解説を「なんJスレ形式」（900〜1000レス）のインフォグラフィックHTML 1ファイルとして生成するスキル。リポジトリ内には何も書き込まず、成果物・中間ファイルはすべて出力先ディレクトリに置く。

## インストール

Claude Code 上で以下を実行する。

```
/plugin marketplace add eda3/eda-skills
/plugin install repo-nanj-thread@eda-skills
```

インストール後に `Run /reload-plugins to activate.` と表示された場合は、続けて `/reload-plugins` を実行する。

## 使い方

対象リポジトリのルートディレクトリで、Claude Code に対して以下のいずれかを入力する。

```
/repo-nanj-thread:repo-nanj-thread
```

または「このリポジトリをなんJスレにして」「なんJ形式で全部解説して」のように自然文で依頼してもよい。

- 引数は取らない。カレントディレクトリ（＝実行時のリポジトリルート）が対象になる。
- リポジトリURLだけを渡してローカルにcloneがない場合は、スキル側が先にcloneを促す。単一ファイルへの質問には使わない（この場合は `repo-doc` などの利用が案内される）。

## 前提条件

- **bash が必須。`sh` では動かない**（SKILL.md に明記。全工程のスクリプトを `bash` で呼び出す前提で書かれている）。Windowsの場合は Git Bash や WSL など、bash が使える環境が必要。
- スクリプトが実行時に呼び出す外部コマンド（`scripts/*.sh` 内で実際に使われているもののみを列挙）:
  - `git`（`inventory.sh` 27〜29行目。`git rev-parse --is-inside-work-tree` と `git ls-files --cached --others --exclude-standard` でファイル一覧を取得。gitリポジトリでない場合は同ファイル30〜31行目で `find` にフォールバックする）
  - `find`（`inventory.sh` 31行目。git非管理時のフォールバックのみ）
  - 標準的なテキスト処理系コマンド: `grep`、`sed`、`awk`、`cut`、`sort`、`uniq`、`comm`、`paste`、`wc`、`cat`、`tr`、`tee`、`date`、`mkdir`、`ls`
    （`inventory.sh`・`make_batches.sh`・`check_read.sh`・`check_plan.sh`・`count_res.sh`・`assemble.sh`・`check_html.sh` の全体で使用。`comm` は `check_plan.sh` 49行目・78行目、`check_html.sh` 46行目で、`paste` は `count_res.sh` 24行目、`check_plan.sh` 50・79行目で使用）
  - `jq`・`rg`（ripgrep）・`curl` は、上記スクリプト内では確認できなかった（未使用）。
- Claude Code 側では、工程2（読了）・工程4（執筆）・工程6（レビュー）でサブエージェントを並列起動する（読了・執筆は同時最大6体）。

## 出力について

成果物はローカル絶対パスを含まない自己完結HTML 1ファイル。`assets/template.html` をベースに `scripts/assemble.sh` が組み立てる。

- レス数は900〜1000（SKILL.md およびチェックスクリプトの既定値）。
- 目次（ブロック別）と、各ブロックのレスを連結した本文を持つ、なんJ掲示板風の単一HTMLページ。
- 外部リソースの読み込みは0個が原則（`<script>` `<link>` `<img>` などのタグは使わず、CSSのみで部品を描く。`check_html.sh` で機械検証される）。
- インフォグラフィック風の部品（ツリー・コード引用・フロー・統計バー・テーブル・コールアウト）を `<style>` 内のクラスで表現する。
- 出力先ディレクトリは既定で `~/nanj-threads/<リポジトリ名>_nanj_<日時>/` 配下（`scripts/inventory.sh` の実装による。`NANJ_OUT` 環境変数で変更可能）。最終HTMLに加え、棚卸し結果・読了記録・構成計画・検証レポートなどの中間ファイルも同ディレクトリに残る。

## ライセンス

未定
