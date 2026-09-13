# なんJスレ 文体・登場人物・レス例

執筆サブエージェントが読む。レスの HTML 形式は html-spec.md、レス数の配分は plan.md に従う。

## 登場人物（ID はこの表のとおりに使う。count_res.sh がこの ID で計測するため）

| 役 | ID | 役割と口調 |
|---|---|---|
| スレ主 | `ID:SureNusi` | >>1 と各ブロック先頭の進行役。「ワイが読んできたで」の当事者口調。まとめ・目次・宣言を担当 |
| 解説ニキ | `ID:KaiSetu9` | 技術解説の主役。断定は根拠（読了記録の quotes やパス）とセットで話す。「〜や。ソースは `src/main.rs` や」 |
| 初心者ニキ | `ID:SyoSinsy` | プログラミング歴ゼロの視点で質問する。読者の疑問の代弁者。質問には後続レスで答えを返す（読者の疑問を放置しないため） |
| ツッコミニキ | `ID:TukKomi7` | 設計の妙・落とし穴に「ファッ!?」と反応してオチを作る。茶化す対象はコードだけ |
| 名無しモブ | `ID:` + 英数8桁（自由） | 相槌・小ボケ・進行の潤滑油。1〜2行 |

## 口調の規約（すべて肯定形で書く）

1. 一人称は「ワイ」、語尾は「〜やで」「〜や」「〜んや」「〜クレメンス」を基調にする（スレの統一感のため）。
2. 定番語彙を使う: 草、サンガツ、ニキ、有能、ファッ!?、〜ンゴ、せやな、はえー。乱発せず1レス1つまで（読みやすさのため）。
3. 笑いはコードとプログラミングあるある（命名センス、コメントの温度差、TODO の化石など）から作る。
   実在の人物・団体・属性の話題が浮かんだら、代わりにコードの話に置き換える。
4. 専門用語はブロック内の初出時に「（＝〜のこと）」と言い換えを添える。前のブロックで説明済みでも短く再掲する
   （読者が目次から途中のブロックに飛んでも分かるようにするため）。
5. 事実の解説は読了記録（read/*.jsonl）に基づき、記録にないことは「未確認やけど推測やと〜」と正直に言う
   （なんJ民は知ったかぶりに厳しいという設定を、正確性の担保に使う）。
6. 罵倒表現はコードの挙動・過去の自分に向ける（「昨日のワイ、無能」）。人に向く言い回しは書き換える。

## レス例（この HTML 形式・この温度感で書く）

### 例1: OP（>>1。スレ主）— README の自己紹介文を原文引用する

```html
<article class="res" data-n="1" id="r1">
<header>風吹けば名無し <span class="id">ID:SureNusi</span></header>
<div class="body">ワイ、3日かけて demo-tool ってリポジトリを全ファイル読破したから初心者向けに解説するで<br>
公式曰く「A tiny CLI that counts words in text files.」、つまりテキストの単語を数えるだけの小さい道具や<br>
コード読めんニキも読み終わる頃には「はえー」ってなっとるはずやから安心してや</div>
</article>
```

### 例2: 解説レス（解説ニキ）— コード部品つき。`<` `>` `&` は実体参照にする

```html
<article class="res" data-n="42" id="r42">
<header>風吹けば名無し <span class="id">ID:KaiSetu9</span></header>
<div class="body">本体の処理は `src/util/count.rs` のここや。たった1行やで<br>
<pre class="ig ig-code"><span class="fn">src/util/count.rs</span><code>pub fn count(s: &amp;str) -&gt; usize {
    s.split_whitespace().count()
}</code></pre>
split_whitespace（＝空白で文字列を切り分ける標準機能のこと）で切って、切れた個数を数えるだけ。単語カウントの正体、これだけなんや</div>
</article>
```

### 例3: 初心者ニキの質問 → 安価つき回答（2レスで1セット）

```html
<article class="res" data-n="43" id="r43">
<header>風吹けば名無し <span class="id">ID:SyoSinsy</span></header>
<div class="body">すまん、<a class="anc" href="#r42">&gt;&gt;42</a>の usize ってなんや？数字なら数字って書けばええやん</div>
</article>
<article class="res" data-n="44" id="r44">
<header>風吹けば名無し <span class="id">ID:KaiSetu9</span></header>
<div class="body"><a class="anc" href="#r43">&gt;&gt;43</a>ええ質問や。usize（＝マイナスにならない整数の型のこと）は「個数」専用の数字や<br>単語の個数が -3 個になることはないやろ？型で「ありえん値」を最初から締め出しとるんや</div>
</article>
```

### 例4: 1行レス（モブ・ツッコミ）— 相槌は短く。ただし1行レスは各ブロック25%まで

```html
<article class="res" data-n="45" id="r45">
<header>風吹けば名無し <span class="id">ID:mobAa12Bb</span></header>
<div class="body">はえー、型って門番なんやな</div>
</article>
```

### 例5: 分からんことを正直に言うレス（規約5の実演）

```html
<article class="res" data-n="46" id="r46">
<header>風吹けば名無し <span class="id">ID:KaiSetu9</span></header>
<div class="body">`src/gen.py` は4万行あって正直全部は読んでへん（部分読解や）<br>冒頭を見る限り自動生成の関数が延々続いとるだけっぽいが、生成元は未確認や。詳しいニキおったら補足頼むで</div>
</article>
```

### 例6: ブロック先頭レス（スレ主）— 宣言＋流れ図。他ブロックへの安価はブロック先頭番号だけに向ける

```html
<article class="res" data-n="111" id="r111">
<header>風吹けば名無し <span class="id">ID:SureNusi</span></header>
<div class="body">ここからエントリポイント編やで。全体像を忘れたニキは<a class="anc" href="#r1">&gt;&gt;1</a>から読み直してや<br>
<div class="ig ig-flow"><div class="ig-title">この編で追う流れ</div><span class="step">起動</span><span class="arrow">→</span><span class="step">引数の解釈</span><span class="arrow">→</span><span class="step">count() 呼び出し</span><span class="arrow">→</span><span class="step">表示</span></div>
今回の主役は `src/main.rs` や</div>
</article>
```
