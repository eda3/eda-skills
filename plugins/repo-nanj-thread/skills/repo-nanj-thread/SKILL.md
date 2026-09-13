---
name: repo-nanj-thread
description: >-
  今いるリポジトリの全ファイルをサブエージェントで読み切り、初心者向けの解説を
  なんJスレ形式（900〜1000レス）のインフォグラフィックHTML 1ファイルとして生成するスキル。
  トリガー例:「このリポジトリをなんJスレにして」「なんJ形式で全部解説して」
  「/repo-nanj-thread」「repo-nanj-threadで読んで」。リポジトリ全体をスレ化したい文脈なら
  明示的にスキル名を呼ばれなくても使ってよい。
  次の場合は使わない: 通常の技術ドキュメントが欲しいとき（repo-docを使う）、
  単一ファイルへの質問、リポジトリURLだけ渡されて手元にcloneがないとき（先にcloneを促す）。
---

# repo-nanj-thread — リポジトリ全読破なんJスレ生成

リポジトリのルートで起動する。成果物はローカル絶対パスを含まない自己完結HTML 1ファイル。
リポジトリ内には何も書き込まない（成果物・中間ファイルはすべて出力ディレクトリへ）。

## 会話に出力してよいもの（これ以外は書かない。HTML本文は会話に貼らない）

1. 工程1の棚卸し要約（summary.txt の転記）
2. 工程2の読了結果（READ_OK/MISSING の行）
3. 工程3の計画要約（スレタイ・ブロック一覧）
4. 工程6の検証結果（check_html.sh の出力と review.md の指摘件数）
5. エラーで中断するときの理由と、どこまで進んだか
6. 完了報告（下の書式）

## 工程0: 準備

- `SKILL_DIR` = この SKILL.md があるディレクトリの絶対パス。一度だけ解決し、以後使い回す。
  不明なら `ls -d ~/.claude/skills/repo-nanj-thread .claude/skills/repo-nanj-thread 2>/dev/null` で確認。
- カレントがリポジトリのルートであることを確認（`ls` に README や src 等が見えるか）。
  違うディレクトリ・cloneがない場合は中断して報告する。
- 以降のスクリプトは必ず `bash` で呼ぶ（`sh` 不可）。

## 工程1: 棚卸し

```bash
bash "$SKILL_DIR/scripts/inventory.sh"          # 最終行が OUT（出力ディレクトリの絶対パス）
bash "$SKILL_DIR/scripts/make_batches.sh" "$OUT" # 標準出力がバッチ数
```

- OUT は `${NANJ_OUT:-$HOME/nanj-threads}/<リポジトリ名>_nanj_<日時>/`。以後すべての工程でこの値を使う。
- summary.txt を会話に転記する。total_files が 0、または 400 を超える場合は中断して相談する
  （400超は工程4のブロック内で紹介しきれない規模のため、対象ディレクトリを絞る提案をする）。
- excluded.txt の除外ファイルは以後読まない。secret 判定のファイルは存在に触れる程度に留める。

## 工程2: 並列読了

- バッチごとに読了サブエージェントを起動（同時に最大6体。終わったら次のバッチ）。
  プロンプトは `references/subagent-prompts.md` の 1 を、{OUT} 等を実パスに展開して使う。
- 全バッチ完了後:

```bash
bash "$SKILL_DIR/scripts/check_read.sh" "$OUT"
```

- `READ_MISSING` なら `$OUT/batches/retry.tsv` を1バッチとして読了エージェントを再投入
  （記録先は read/retry1.jsonl 等の新規ファイル）。READ_OK になるまで繰り返す（最大3周。
  3周しても unreadable が残る場合は、そのファイルの status=unreadable 記録があることを確認して先へ進む）。

## 工程3: 構成計画

- 計画サブエージェント1体（プロンプト2）。成果物は plan/blocks.tsv・assign.tsv・plan.md。
- 完了後に自分でも検算する:

```bash
bash "$SKILL_DIR/scripts/check_plan.sh" "$OUT"
```

- RESULT FAIL なら FAIL 行を添えて計画エージェントに差し戻す（最大3回。直らなければ中断して報告）。
- PASS したらスレタイとブロック一覧を会話に出す。

## 工程4: 並列執筆

- blocks.tsv の1ブロックにつき執筆サブエージェント1体（プロンプト3。同時に最大6体）。
  {NN}{START}{END}{THEME} は blocks.tsv の行から展開する。
- 執筆エージェントは自分で `count_res.sh` を最大3回回して RESULT OK まで直す契約。
  NG 報告が返ってきたブロックだけ、NG 理由を添えて新しい執筆エージェントで書き直す（最大2回）。

## 工程5: 組み立て

```bash
bash "$SKILL_DIR/scripts/assemble.sh" "$OUT" "$SKILL_DIR"   # 最終行が最終HTMLの絶対パス
```

## 工程6: 検証とレビュー

```bash
bash "$SKILL_DIR/scripts/check_html.sh" "$OUT" "$SKILL_DIR"
```

- RESULT FAIL の項目は該当ブロックを特定し、そのブロックの執筆エージェントに FAIL 行ごと差し戻して
  工程4→5→6をやり直す（最大2周。直らなければ FAIL 内容を添えて中断報告）。
- PASS 後、レビューサブエージェント1体（プロンプト4）で review.md を作る。
  指摘があれば該当ブロックだけ修正→工程5→6を再実行。指摘0件または2周したら確定。
- 検証結果と指摘件数を会話に出す。

## 完了報告（この書式で会話に出して終了）

- 成果物: 最終HTMLの絶対パス（claude.ai 上なら present_files でも提示）
- 実測: レス数 / ブロック数 / 対象ファイル数（除外数）/ 総行数（すべて check_html・summary の計測値）
- 未確認・partial・unreadable として扱ったファイルの一覧（なければ「なし」）
- レビュー指摘の残件（あれば）

## 守ること（全工程共通）

- 数値はスクリプトの計測値だけを使う。目視の概算・雰囲気の数字を書かない。
- 成果物にローカル絶対パスを書かない（check_html.sh が $HOME の3表記で検査する）。
- リポジトリの内容について記録にないことは断定しない。「未確認」と書く文化はこのスキルの仕様。
- 中間ファイルの削除はしない（OUT 配下は再実行・デバッグの記録として残す）。
