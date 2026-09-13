# サブエージェント用プロンプト（4種）

`{OUT}` `{SKILL_DIR}` `{REPO_ROOT}` `{NN}` `{START}` `{END}` `{THEME}` `{HTML}` は、
オーケストレーターが**実際の絶対パス・数値に置き換えてから**渡す（サブエージェントは環境変数を引き継がない）。
`{HTML}` は assemble.sh が最終行に出力する最終HTMLの絶対パス。

## 1. 読了エージェント（工程2。バッチ1個につき1体）

```
<task>
リポジトリ {REPO_ROOT} のファイル読了係。{OUT}/batches/{NN}.tsv の各行
（path, bytes, lines, ext, large）のファイルを1つずつ読み、1ファイル=1行のJSONで
{OUT}/read/{NN}.jsonl に記録する。
</task>
<constraints>
- 出力は {OUT}/read/{NN}.jsonl のみ。リポジトリのファイルは読み取り専用で扱う。
- JSONは1行1オブジェクト。キーと値の規約:
  path: バッチのpath列を一字一句そのまま
  status: "full"(全読) / "partial"(large=1で先頭・末尾・構造のみ) / "unreadable"(読めない。理由をnoteへ)
  role: このファイルの役割ひとこと(日本語)
  summary: 内容の要約2〜4文(日本語)。誰向けか・何をするかを書く
  key_symbols: 主要な関数/型/設定キー名の配列(最大10)
  depends_on: このファイルが参照する他のリポジトリ内パスの配列(分かる範囲)
  gotchas: 初心者が驚きそうな点・落とし穴の配列(最大5、日本語)
  quotes: 引用に使えそうな短い原文の配列(最大3)。各要素は "L<行番号>: <原文>" 形式
  terms: 登場する専門用語と一言説明の配列(最大8)。"用語=説明" 形式
  note: 補足(なければ空文字)
- JSON文字列内の二重引用符とバックスラッシュはエスケープする。改行は \n にする。
- large=1 のファイルは partial でよい。読んだ範囲を note に書く。
- 感想や推測を書くときは summary/gotchas 内で「推測:」と明示する。
- 割り当て作業は自分で完了する（さらにサブエージェントを起動せず、深さは本 SKILL からの1段に固定。費用と記録の追跡のため）。
</constraints>
```

## 2. 計画エージェント（工程3。1体）

```
<task>
なんJスレの構成作家。{OUT}/summary.txt と {OUT}/read/*.jsonl を全部読み、
900〜1000レスのスレ構成を3ファイルに書く。
</task>
<constraints>
- 出力は {OUT}/plan/ 配下の3ファイルのみ。
- blocks.tsv: block(01〜) <TAB> start <TAB> end <TAB> theme。ヘッダ行なし。
  8〜12ブロック、各70〜130レス を推奨（範囲外は check_plan.sh が WARN で知らせる）。start は 1 から連番。合計900〜1000（下の自己チェックで判定）。
  構成順は「読者が理解しやすい順」（全体像→入口→中核→周辺→運用→総まとめ）。
- assign.tsv: path <TAB> block <TAB> mode。inventory.tsv の全パスをどこかのブロックに載せる。
  自動生成などで束にして扱うディレクトリは、ディレクトリパス1行 mode=dir で代表させてよい
  （そのディレクトリ名は本文に必ず登場させる前提になる）。それ以外は mode=file。
- plan.md: 1行目に「title: <スレタイ>」。スレタイは【朗報】等の定番プレフィックス+リポジトリ名入り。
  続けて、各ブロックの狙い1〜2文、ブロック先頭レス番号の一覧、笑いどころにできそうな gotchas の候補を書く。
- 書き終えたら bash {SKILL_DIR}/scripts/check_plan.sh {OUT} 900 1000 を実行し、
  RESULT PASS になるまで直す（最大3回）。3回で直らなければ最後の出力を残して FAIL 行を報告する。
- 割り当て作業は自分で完了する（さらにサブエージェントを起動せず、深さは本 SKILL からの1段に固定。費用と記録の追跡のため）。
</constraints>
```

## 3. 執筆エージェント（工程4。ブロック1個につき1体）

```
<task>
なんJスレの執筆担当。ブロック{NN}「{THEME}」、レス >>{START} 〜 >>{END} を書き、
{OUT}/parts/{NN}.html に保存する。
</task>
<input>
- 構成台本: {OUT}/plan/plan.md と {OUT}/plan/blocks.tsv（他ブロックの範囲・先頭番号の確認用）
- 担当ファイルの読了記録: {OUT}/read/*.jsonl のうち {OUT}/plan/assign.tsv で block={NN} の path の行
- 文体と登場人物: {SKILL_DIR}/references/nanj-style.md
- HTML書式と部品カタログ: {SKILL_DIR}/references/html-spec.md
</input>
<constraints>
- 出力は {OUT}/parts/{NN}.html のみ。
- 内容の根拠は読了記録に限る。nanj-style.md 規約5 に従う。
- 担当ブロックに割り当てられた全ファイルのパスを本文に登場させる（mode=dir はディレクトリパスを登場させる）。
- 配分: インフォグラフィック部品3個以上 / 初心者ニキ15%以上 / 1行レス25%以下。
- 書き終えたら bash {SKILL_DIR}/scripts/count_res.sh {OUT}/parts/{NN}.html {START} {END} を実行し、
  RESULT OK になるまで直す（最大3回）。3回で直らなければ最後の出力を残して NG 理由を報告する。
- 割り当て作業は自分で完了する（さらにサブエージェントを起動せず、深さは本 SKILL からの1段に固定。費用と記録の追跡のため）。
</constraints>
```

## 4. レビューエージェント（工程6の任意追加。1体）

```
<task>
読者代表のレビュー係。{HTML} を通読し、機械検証では拾えない品質を確認して
{OUT}/review.md に指摘を書く。修正はしない。
</task>
<constraints>
- 観点: (1)初心者が置いていかれる箇所（用語の説明漏れ） (2)ブロック間で説明が矛盾する箇所
  (3)キャラ崩壊（IDと口調の不一致） (4)笑いが人や属性に向いている箇所 (5)同じ小ネタの使い回し。
- 指摘は「レス番号 / 種別 / 指摘 / 修正案」の表形式。0件なら「指摘なし」と書く。
- 出力は {OUT}/review.md のみ。
- 割り当て作業は自分で完了する（さらにサブエージェントを起動せず、深さは本 SKILL からの1段に固定。費用と記録の追跡のため）。
</constraints>
```
