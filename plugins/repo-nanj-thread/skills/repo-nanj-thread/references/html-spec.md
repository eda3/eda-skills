# parts/NN.html の書式契約とインフォグラフィック部品カタログ

執筆サブエージェントが読む。CSS はテンプレート（assets/template.html）に定義済みなので、
part ファイルには **HTML 断片だけ** を書く。`<style>` `<html>` `<head>` `<body>` は書かない。

## part ファイルの契約（違反すると count_res.sh / check_html.sh で NG になる）

1. ファイルの中身は `<article class="res" ...>` 要素の連なり **のみ**（間の空行・改行は可）。
2. レス1件の形は必ずこれ。`data-n` と `id="rN"` の N は同じ値にする:

```html
<article class="res" data-n="123" id="r123">
<header>風吹けば名無し <span class="id">ID:XXXXXXXX</span></header>
<div class="body">本文</div>
</article>
```

3. `data-n` は担当範囲 start〜end の **連番**。飛ばさない・重複させない・範囲外を書かない。
   レス番号の表示はテンプレートの CSS が `data-n` から描くので、本文に番号を書く必要はない。
4. 担当ブロックの先頭レス（data-n=start）はスレ主 `ID:SureNusi` の進行レスにする（目次のリンク先になる）。
5. 安価は `<a class="anc" href="#rN">&gt;&gt;N</a>`。N に使えるのは
   (a) 自ブロック内の番号、(b) 他ブロックの**先頭番号**（plan.md に一覧がある）、(c) `1`。
   それ以外の他ブロック番号は並列執筆中で存在保証がないため使えない。
6. リソース系タグは書かない: `<script>` `<link>` `<img>` `<iframe>` `<embed>` `<object>` `<video>` `<audio>`。
   図解はすべて下の CSS 部品で描く（画像なしで自己完結させるため）。
7. コード・設定・ログを引用するときは `<` → `&lt;`、`>` → `&gt;`、`&` → `&amp;` に必ず変換する。
   安価の `&gt;&gt;` 以外で生の `<` が本文に混ざると、タグ扱いされて表示が壊れる。
8. ローカルの絶対パス（クローン先など）は書かない。ファイルは常にリポジトリルートからの相対パス
   （inventory.tsv の表記そのまま）で呼ぶ。これが check_html.sh のファイル網羅チェックの照合キーになる。

## インフォグラフィック部品カタログ（class="ig ..." で始める。各ブロック3個以上）

### ディレクトリツリー `.ig-tree`（pre 要素。罫線は │ ├ └ ─）
```html
<pre class="ig ig-tree"><span class="fn">構成</span>src/
├── main.rs        ← 入口
└── util/
    └── count.rs   ← 本体ロジック</pre>
```

### コード引用 `.ig-code`（pre 要素。fn 行に必ずファイルパス）
```html
<pre class="ig ig-code"><span class="fn">src/main.rs</span><code>fn main() {
    println!(&quot;hello&quot;);
}</code></pre>
```

### 流れ図 `.ig-flow`（手順・データフロー）
```html
<div class="ig ig-flow"><div class="ig-title">処理の流れ</div>
<span class="step">入力</span><span class="arrow">→</span><span class="step">分割</span><span class="arrow">→</span><span class="step">計数</span><span class="arrow">→</span><span class="step">出力</span></div>
```

### 横棒グラフ `.ig-stat`（規模比較など。--w は 0〜100%）
```html
<div class="ig ig-stat"><div class="ig-title">ファイル規模（行数）</div>
<div class="row"><span class="label">src/gen.py</span><div class="bar" style="--w:100%"></div><span class="val">40001</span></div>
<div class="row"><span class="label">README.md</span><div class="bar" style="--w:1%"></div><span class="val">5</span></div></div>
```
数値は読了記録・inventory.tsv の実測値だけを書く。概算で作らない。

### 比較表 `.ig-table`
```html
<div class="ig ig-table"><div class="ig-title">2つの関数の役割</div>
<table><tr><th>関数</th><th>やること</th></tr>
<tr><td>main</td><td>起動と表示</td></tr>
<tr><td>count</td><td>単語を数える</td></tr></table></div>
```

### 注意書き `.ig-callout`（初心者向けポイント・落とし穴）
```html
<div class="ig ig-callout"><div class="ig-title">初心者向けポイント</div>
リポジトリは上から順に読まなくてええんやで。入口（main）から呼ばれる順に追うんや</div>
```

## 自己チェック（執筆後に必ず実行）

```bash
bash "$SKILL_DIR/scripts/count_res.sh" "$OUT/parts/NN.html" <start> <end>
```
`RESULT OK` が出るまで直す（最大3回）。NG 理由は出力に日本語で書いてある。
