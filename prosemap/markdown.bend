# Markdown block extractor — the source adapter.
#
# Design note (replaces the HTML parser): prosemap-bend ingests Markdown, not
# HTML. Markdown is line-oriented, which fits Bend's structural recursion (walk
# the line list, no fuel needed) and keeps the adapter small. External tools
# (pandoc, etc.) convert HTML/other formats to Markdown on the way in.
#
# Extracts a flat List<Block>: ATX headings (`#`..`######`), fenced code,
# fenced `math` blocks, and blank-line-separated paragraphs. Inline `$...$`
# and display `$$...$$` tokens are attached to their containing prose/heading
# block. Byte offsets are tracked so each block's evidence excerpt is an exact
# slice of the source.
import Base
import ./types.bend as T
import ./contracts.bend as C
import ./utf8.bend as Utf8

# accumulator state while folding over lines; MdPara/MdCode carry the section
# anchor in effect when the block started.
type MdSt is Data:
  MdNone{}
  MdPara{buf: String, start: U32, end: U32, sec: String}
  MdCode{buf: String, start: U32, end: U32, sec: String, math: Bool}

# one line's contribution: blocks to emit, the next state, and the section
# anchor in effect for the NEXT line (changed only by headings).
type Step is Data:
  Step{emit: List<&2, T.Block>, state: MdSt, sec: String}

def Md.step_emit(s: Step) -> List<&2, T.Block>:
  match s:
    case Step{emit, state, sec}:
      emit

def Md.step_state(s: Step) -> MdSt:
  match s:
    case Step{emit, state, sec}:
      state

def Md.step_sec(s: Step) -> String:
  match s:
    case Step{emit, state, sec}:
      sec

# line classification
type LC is Data:
  LcFence{}
  LcHeading{}
  LcBlank{}
  LcText{}

# ---------------------------------------------------------------------------
# small string helpers
# ---------------------------------------------------------------------------
# self-recursive (a helper that called back into ltrim would be mutual recursion)
def Md.ltrim(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{+c, +t}:
      Bool.pick(String, Char.is_space(c), Md.ltrim(t), SCon{c, t})

def Md.trim(s: String) -> String:
  String.reverse(Md.ltrim(String.reverse(Md.ltrim(s))))

def Md.aln(empty: Bool, buf: String, line: String) -> String:
  match empty:
    case True{}:
      line
    case False{}:
      buf ++ "\n" ++ line

def Md.appendln(+buf: String, line: String) -> String:
  Md.aln(String.is_empty(buf), buf, line)

def Md.is_blank(s: String) -> Bool:
  String.is_empty(Md.ltrim(s))

# leading '#' count (self-recursive)
def Md.hcount(s: String) -> Nat:
  match s:
    case SNil{}:
      0n
    case SCon{c, t}:
      Bool.pick(Nat, U32.is_eq(Char.to_u32(c), 35), 1n+Md.hcount(t), 0n)

def Md.space_after(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{c, t}:
      Char.is_space(c)

def Md.ih(+h: Nat, +line: String) -> Bool:
  Bool.and(Bool.and(Nat.is_ge(h, 1n), Nat.is_le(h, 6n)), Md.space_after(String.drop(line, h)))

def Md.is_heading(+line: String) -> Bool:
  Md.ih(Md.hcount(line), line)

# ---------------------------------------------------------------------------
# classification (priority: fence > heading > blank > text)
# ---------------------------------------------------------------------------
def Md.cl3(b: Bool) -> LC:
  match b:
    case True{}:
      LcBlank{}
    case False{}:
      LcText{}

def Md.cl2(h: Bool, +line: String) -> LC:
  match h:
    case True{}:
      LcHeading{}
    case False{}:
      Md.cl3(Md.is_blank(line))

def Md.cl1(f: Bool, +line: String) -> LC:
  match f:
    case True{}:
      LcFence{}
    case False{}:
      Md.cl2(Md.is_heading(line), line)

def Md.classify(+line: String) -> LC:
  Md.cl1(String.starts_with(line, "```"), line)

# A math fence is exactly a backtick fence whose trimmed info string is `math`.
# Other fenced languages, including `mathjax`, remain ordinary source code.
def Md.is_math_fence(+line: String) -> Bool:
  String.eq(String.to_lower(Md.trim(String.drop(line, 3n))), "math")

# ---------------------------------------------------------------------------
# block builders
# ---------------------------------------------------------------------------
# --- Markdown link extraction: [text](#frag) -> internal fragment link -------
# A char-by-char state machine (single self-recursive scan; helpers that recursed
# back into the scan would be mutual recursion, which Bend forbids). It matches
# the marker "](#" then collects the fragment until ')'.
type LkSt is Data:
  LkScan{np: Nat}       # matched np chars (0..2) of "](#"
  LkFrag{buf: String}   # collecting the fragment

type LkStep is Data:
  LkStep{st: LkSt, emit: Maybe<&2, T.Link>}

def Md.lkstep_st(s: LkStep) -> LkSt:
  match s:
    case LkStep{st, emit}:
      st

def Md.lkstep_emit(s: LkStep) -> Maybe<&2, T.Link>:
  match s:
    case LkStep{st, emit}:
      emit

def Md.needle_at(np: Nat) -> U32:
  match np:
    case 0n:
      93
    case 1n+p:
      match p:
        case 0n:
          40
        case 1n+q:
          35

def Md.lk_scan_adv(at2: Bool, +np: Nat) -> LkStep:
  match at2:
    case True{}:
      LkStep{LkFrag{""}, None{}}
    case False{}:
      LkStep{LkScan{1n+np}, None{}}

def Md.lk_scan(matched: Bool, +np: Nat) -> LkStep:
  match matched:
    case True{}:
      Md.lk_scan_adv(Nat.is_eq(np, 2n), np)
    case False{}:
      LkStep{LkScan{0n}, None{}}

def Md.lk_frag(isClose: Bool, c: Char, +buf: String, +eid: String) -> LkStep:
  match isClose:
    case True{}:
      LkStep{LkScan{0n}, Some{T.Link{"#" ++ buf, Some{buf}, None{}, eid}}}
    case False{}:
      LkStep{LkFrag{buf ++ SCon{c, SNil{}}}, None{}}

def Md.lk_step(+c: Char, st: LkSt, +eid: String) -> LkStep:
  match st:
    case LkScan{+np}:
      Md.lk_scan(U32.is_eq(Char.to_u32(c), Md.needle_at(np)), np)
    case LkFrag{buf}:
      Md.lk_frag(U32.is_eq(Char.to_u32(c), 41), c, buf, eid)

def Md.lk_prepend(m: Maybe<&2, T.Link>, acc: List<&2, T.Link>) -> List<&2, T.Link>:
  match m:
    case None{}:
      acc
    case Some{l}:
      l <> acc

def Md.lk_go(s: String, st: LkSt, +eid: String, acc: List<&2, T.Link>) -> List<&2, T.Link>:
  match s:
    case SNil{}:
      List.reverse(&2, T.Link, acc)
    case SCon{+c, t}:
      +step = Md.lk_step(c, st, eid)
      Md.lk_go(t, Md.lkstep_st(step), eid, Md.lk_prepend(Md.lkstep_emit(step), acc))

def Md.links(+text: String, +eid: String) -> List<&2, T.Link>:
  Md.lk_go(text, LkScan{0n}, eid, Nil{})

# ---------------------------------------------------------------------------
# TeX extraction
# ---------------------------------------------------------------------------
# Tokens are deliberately attached to existing block evidence: their raw
# spelling is source-derived while their evidence ID continues to name the
# enclosing Markdown block. A lone/unclosed delimiter is ordinary prose.
type TexSt is Data:
  TexScan{}
  TexInline{buf: String}
  TexDisplay{buf: String}

type TexStep is Data:
  TexDone{}
  TexNext{rest: String, st: TexSt}
  TexEmit{raw: String, display: Bool, rest: String, st: TexSt}

def Md.is_dollar(c: Char) -> Bool:
  U32.is_eq(Char.to_u32(c), 36)

def Md.tex_nonempty(+raw: String) -> Bool:
  Bool.not(String.is_empty(Md.trim(raw)))

def Md.tex_push_k(nonempty: Bool, +raw: String, display: Bool, +eid: String, acc: List<&2, T.Tex>) -> List<&2, T.Tex>:
  match nonempty:
    case False{}:
      acc
    case True{}:
      T.Tex{raw, display, True{}, eid} <> acc

def Md.tex_push(+raw: String, display: Bool, +eid: String, acc: List<&2, T.Tex>) -> List<&2, T.Tex>:
  Md.tex_push_k(Md.tex_nonempty(raw), raw, display, eid, acc)

def Md.tex_scan_double(double: Bool, +d: Char, +more: String) -> TexStep:
  match double:
    case False{}:
      TexNext{SCon{d, more}, TexInline{""}}
    case True{}:
      TexNext{more, TexDisplay{""}}

def Md.tex_scan_dollar(+tail: String) -> TexStep:
  match tail:
    case SNil{}:
      TexDone{}
    case SCon{d, +more}:
      Md.tex_scan_double(Md.is_dollar(d), d, more)

def Md.tex_scan_step(dollar: Bool, +tail: String) -> TexStep:
  match dollar:
    case False{}:
      TexNext{tail, TexScan{}}
    case True{}:
      Md.tex_scan_dollar(tail)

def Md.tex_inline_step(dollar: Bool, +c: Char, +tail: String, +buf: String) -> TexStep:
  match dollar:
    case False{}:
      TexNext{tail, TexInline{buf ++ SCon{c, SNil{}}}}
    case True{}:
      TexEmit{buf, False{}, tail, TexScan{}}

def Md.tex_display_dollar(double: Bool, +d: Char, +more: String, +buf: String) -> TexStep:
  match double:
    case False{}:
      TexNext{SCon{d, more}, TexDisplay{buf ++ "$"}}
    case True{}:
      TexEmit{buf, True{}, more, TexScan{}}

def Md.tex_display_char(dollar: Bool, +c: Char, +tail: String, +buf: String) -> TexStep:
  match dollar:
    case False{}:
      TexNext{tail, TexDisplay{buf ++ SCon{c, SNil{}}}}
    case True{}:
      match tail:
        case SNil{}:
          TexDone{}
        case SCon{d, +more}:
          Md.tex_display_dollar(Md.is_dollar(d), d, more, buf)

def Md.tex_display_step(+c: Char, +tail: String, +buf: String) -> TexStep:
  Md.tex_display_char(Md.is_dollar(c), c, tail, buf)

def Md.tex_step(s: String, st: TexSt) -> TexStep:
  match s:
    case SNil{}:
      TexDone{}
    case SCon{+c, +tail}:
      match st:
        case TexScan{}:
          Md.tex_scan_step(Md.is_dollar(c), tail)
        case TexInline{+buf}:
          Md.tex_inline_step(Md.is_dollar(c), c, tail, buf)
        case TexDisplay{+buf}:
          Md.tex_display_step(c, tail, buf)


def Md.tex_apply(fuel: Nat, step: TexStep, +eid: String, acc: List<&2, T.Tex>) -> List<&2, T.Tex>:
  match fuel:
    case 0n:
      List.reverse(&2, T.Tex, acc)
    case 1n+p:
      match step:
        case TexDone{}:
          List.reverse(&2, T.Tex, acc)
        case TexNext{rest, st}:
          Md.tex_apply(p, Md.tex_step(rest, st), eid, acc)
        case TexEmit{raw, display, rest, st}:
          Md.tex_apply(p, Md.tex_step(rest, st), eid, Md.tex_push(raw, display, eid, acc))

def Md.tex(+text: String, +eid: String) -> List<&2, T.Tex>:
  Md.tex_apply(1n+String.length(text), Md.tex_step(text, TexScan{}), eid, Nil{})

def Md.add_tex(b: T.Block, tex: List<&2, T.Tex>) -> T.Block:
  match b:
    case T.Block{blockId, kind, tagName, sectionAnchor, authoredId, headingLevel, ancestorSections, text, mapped, evidence, links, oldTex}:
      T.Block{blockId, kind, tagName, sectionAnchor, authoredId, headingLevel, ancestorSections, text, mapped, evidence, links, tex}

def Md.eid(start: U32) -> String:
  "ev-" ++ Nat.show(U32.to_nat(start))
def Md.block(+tag: String, kind: T.BlockKind, evk: T.EvidenceKind, level: Maybe<&2, U32>, +start: U32, end: U32, +text: String, +sec: String, +authored: Maybe<&2, String>, docsha: String, +src: String) -> T.Block:
  +sid = Nat.show(U32.to_nat(start))
  +eid = Md.eid(start)
  +links = Md.links(text, eid)
  ev = C.Evidence.mk(eid, docsha, "input.md", start, end, text, {T.Anchor{sec, None{}} : T.Anchor}, evk, src)
  T.Block{"blk-" ++ sid, kind, tag, sec, authored, level, [], text, True{}, [ev], links, []}
def Md.inline_block(+tag: String, kind: T.BlockKind, evk: T.EvidenceKind, level: Maybe<&2, U32>, +start: U32, end: U32, +text: String, +sec: String, +authored: Maybe<&2, String>, docsha: String, +src: String) -> T.Block:
  Md.add_tex(Md.block(tag, kind, evk, level, start, end, text, sec, authored, docsha, src), Md.tex(text, Md.eid(start)))


def Md.htag(h: Nat) -> String:
  "h" ++ Nat.show(h)

# a heading opens a new section anchored at its own byte offset
def Md.heading_sec(offset: U32) -> String:
  "sec-" ++ Nat.show(U32.to_nat(offset))

# --- {#slug} heading anchors -----------------------------------------------
# `## Methods {#methods}` -> section anchor + authored id "methods", slug
# stripped from the title. Human-named anchors make routes and links readable.
def Md.after2(fuel: Nat, +hay: String, +needle: String) -> Maybe<&2, String>:
  match fuel:
    case 0n:
      None{}
    case 1n+p:
      Bool.pick(Maybe<&2, String>, String.starts_with(hay, needle),
        Some{String.drop(hay, String.length(needle))},
        Md.after2(p, String.drop(hay, 1n), needle))

def Md.until_brace(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{+c, t}:
      Bool.pick(String, U32.is_eq(Char.to_u32(c), 125), "", SCon{c, Md.until_brace(t)})

# `{#}` names nothing: an empty slug is None, so the section keeps its offset
# anchor instead of collapsing every following block onto an empty anchor.
def Md.slug_of(+s: String) -> Maybe<&2, String>:
  Bool.pick(Maybe<&2, String>, String.is_empty(s), None{}, Some{s})

def Md.slug_pick(m: Maybe<&2, String>) -> Maybe<&2, String>:
  match m:
    case None{}:
      None{}
    case Some{rest}:
      Md.slug_of(Md.until_brace(rest))

# the {#slug} of a heading line, or None
def Md.line_slug(+line: String) -> Maybe<&2, String>:
  Md.slug_pick(Md.after2(String.length(line), line, "{#"))

def Md.hc_pick(m: Maybe<&2, Char>) -> Char:
  match m:
    case Some{c}:
      c
    case None{}:
      Chr{32}

def Md.head_char(s: String) -> Char:
  Md.hc_pick(String.get(s, 0n))

# prefix of s before the first occurrence of needle (whole s if absent)
def Md.before_needle(fuel: Nat, +s: String, +needle: String) -> String:
  match fuel:
    case 0n:
      ""
    case 1n+p:
      Bool.pick(String, Bool.or(String.is_empty(s), String.starts_with(s, needle)),
        "",
        SCon{Md.head_char(s), Md.before_needle(p, String.drop(s, 1n), needle)})

# title with any trailing {#slug} removed
def Md.strip_slug(+title: String) -> String:
  Md.trim(Md.before_needle(String.length(title), title, "{#"))

def Md.hn_pick(m: Maybe<&2, String>, offset: U32) -> String:
  match m:
    case Some{s}:
      s
    case None{}:
      Md.heading_sec(offset)

# the section anchor a heading opens: its {#slug}, else sec-<offset>
def Md.heading_nsec(+line: String, +offset: U32) -> String:
  Md.hn_pick(Md.line_slug(line), offset)

def Md.heading_block(+line: String, +offset: U32, len: U32, +sec: String, docsha: String, +src: String) -> List<&2, T.Block>:
  +h = Md.hcount(line)
  [ Md.inline_block(Md.htag(h), T.BkHeading{}, T.EvHeading{}, Some{U32.from_nat(h)}, offset, U32.add(offset, len), Md.strip_slug(Md.trim(String.drop(line, h))), sec, Md.line_slug(line), docsha, src) ]

def Md.para_block(buf: String, +start: U32, pend: U32, +sec: String, docsha: String, +src: String) -> List<&2, T.Block>:
  [ Md.inline_block("p", T.BkProse{}, T.EvProse{}, None{}, start, pend, buf, sec, None{}, docsha, src) ]

def Md.code_block(buf: String, +start: U32, cend: U32, +sec: String, docsha: String, +src: String) -> List<&2, T.Block>:
  [ Md.block("pre", T.BkPre{}, T.EvSourcePattern{}, None{}, start, cend, buf, sec, None{}, docsha, src) ]

def Md.math_block(+buf: String, +start: U32, mend: U32, +sec: String, docsha: String, +src: String) -> List<&2, T.Block>:
  [ Md.add_tex(Md.block("math", T.BkMath{}, T.EvTex{}, None{}, start, mend, buf, sec, None{}, docsha, src), Md.tex_push(buf, True{}, Md.eid(start), Nil{})) ]

# ---------------------------------------------------------------------------
# per-line dispatch (non-recursive; returns a Step)
# ---------------------------------------------------------------------------
# state None, no pending block. `cur` is the section in effect.
def Md.normal(lc: LC, +line: String, +offset: U32, len: U32, +noff: U32, +cur: String, docsha: String, +src: String) -> Step:
  match lc:
    case LcFence{}:
      Step{Nil{}, MdCode{"", noff, noff, cur, Md.is_math_fence(line)}, cur}
    case LcHeading{}:
      +nsec = Md.heading_nsec(line, offset)
      Step{Md.heading_block(line, offset, len, nsec, docsha, src), MdNone{}, nsec}
    case LcBlank{}:
      Step{Nil{}, MdNone{}, cur}
    case LcText{}:
      Step{Nil{}, MdPara{line, offset, U32.add(offset, len), cur}, cur}

# state Para{buf,start,pend,psec}
def Md.para(lc: LC, +line: String, +buf: String, +start: U32, pend: U32, +psec: String, +offset: U32, len: U32, +noff: U32, +cur: String, +docsha: String, +src: String) -> Step:
  match lc:
    case LcFence{}:
      Step{Md.para_block(buf, start, pend, psec, docsha, src), MdCode{"", noff, noff, cur, Md.is_math_fence(line)}, cur}
    case LcHeading{}:
      +nsec = Md.heading_nsec(line, offset)
      Step{List.append(&2, T.Block, Md.para_block(buf, start, pend, psec, docsha, src), Md.heading_block(line, offset, len, nsec, docsha, src)), MdNone{}, nsec}
    case LcBlank{}:
      Step{Md.para_block(buf, start, pend, psec, docsha, src), MdNone{}, cur}
    case LcText{}:
      Step{Nil{}, MdPara{Md.appendln(buf, line), start, U32.add(offset, len), psec}, cur}

# state Code{buf,start,cend,csec}
def Md.code_emit(math: Bool, +buf: String, +start: U32, end: U32, +sec: String, docsha: String, +src: String) -> List<&2, T.Block>:
  match math:
    case False{}:
      Md.code_block(buf, start, end, sec, docsha, src)
    case True{}:
      Md.math_block(buf, start, end, sec, docsha, src)

def Md.code_line(isFence: Bool, +line: String, +buf: String, +start: U32, cend: U32, +csec: String, math: Bool, offset: U32, len: U32, +cur: String, docsha: String, +src: String) -> Step:
  match isFence:
    case True{}:
      Step{Md.code_emit(math, buf, start, cend, csec, docsha, src), MdNone{}, cur}
    case False{}:
      Step{Nil{}, MdCode{Md.appendln(buf, line), start, U32.add(offset, len), csec, math}, cur}

def Md.step(state: MdSt, +line: String, offset: U32, len: U32, noff: U32, +cur: String, docsha: String, +src: String) -> Step:
  match state:
    case MdNone{}:
      Md.normal(Md.classify(line), line, offset, len, noff, cur, docsha, src)
    case MdPara{buf, start, pend, psec}:
      Md.para(Md.classify(line), line, buf, start, pend, psec, offset, len, noff, cur, docsha, src)
    case MdCode{buf, start, cend, csec, math}:
      Md.code_line(String.starts_with(line, "```"), line, buf, start, cend, csec, math, offset, len, cur, docsha, src)

# ---------------------------------------------------------------------------
# fold over lines (self-recursive; step is computed then projected)
# ---------------------------------------------------------------------------
def Md.flush(state: MdSt, docsha: String, +src: String) -> List<&2, T.Block>:
  match state:
    case MdNone{}:
      Nil{}
    case MdPara{buf, start, pend, psec}:
      Md.para_block(buf, start, pend, psec, docsha, src)
    case MdCode{buf, start, cend, csec, math}:
      Md.code_emit(math, buf, start, cend, csec, docsha, src)

def Md.go(lines: List<&2, String>, +offset: U32, state: MdSt, +cur: String, +docsha: String, +src: String) -> List<&2, T.Block>:
  match lines:
    case Nil{}:
      Md.flush(state, docsha, src)
    case Con{+line, rest}:
      +len  = Utf8.Utf8.byte_length(line)
      +noff = U32.add(U32.add(offset, len), 1)
      +step = Md.step(state, line, offset, len, noff, cur, docsha, src)
      List.append(&2, T.Block, Md.step_emit(step), Md.go(rest, noff, Md.step_state(step), Md.step_sec(step), docsha, src))

def Md.parse(+src: String, +docsha: String) -> List<&2, T.Block>:
  Md.go(String.lines(src), 0, MdNone{}, "root", docsha, src)
