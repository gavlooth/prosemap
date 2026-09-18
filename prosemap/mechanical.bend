# Deterministic mechanical rules.
#
# v1 ports a representative subset across three dimensions, each operating
# directly on the extracted Block list (no evidence-index / authoredId map yet):
#   - structure.heading-depth       (candidate)   headingLevel > threshold
#   - terminology.definition        (observation) <dfn> blocks
#   - source.escaped-pipe           (candidate)   >=2 lines with >=2 "\|"
# The remaining rules (transitions, duplicate ids, unresolved links, ARI,
# case-similar notation, ascii-diagram, ...) follow the same shape.
#
# Finding identity: a canonical string over rule + evidence
# (kind, rawExcerpt, span) is hashed with our verified SHA-256; recordId is
# `<rule.id>:<fingerprint[:20]>`. Byte-parity with any external stableHash JSON is a
# separate goal (the gate re-runs THIS function, so it is self-consistent).
import Base
import ./types.bend as T
import ./sha256.bend as S

# --- rule catalogue --------------------------------------------------------
def Mech.rule_heading_depth() -> T.RuleRef:
  T.RuleRef{"structure.heading-depth", "1"}

def Mech.rule_definition() -> T.RuleRef:
  T.RuleRef{"terminology.definition", "1"}

def Mech.rule_escaped_pipe() -> T.RuleRef:
  T.RuleRef{"source.escaped-pipe", "1"}

def Mech.rule_heading_transition() -> T.RuleRef:
  T.RuleRef{"structure.heading-transition", "1"}

def Mech.rule_unresolved() -> T.RuleRef:
  T.RuleRef{"reference.unresolved", "1"}

def Mech.rule_ascii_diagram() -> T.RuleRef:
  T.RuleRef{"source.ascii-diagram", "1"}

def Mech.rule_duplicate_id() -> T.RuleRef:
  T.RuleRef{"structure.duplicate-id", "1"}

def Mech.rule_ari() -> T.RuleRef:
  T.RuleRef{"formula.ari", "1"}

def Mech.rule_term_density() -> T.RuleRef:
  T.RuleRef{"terminology.introduction-density", "1"}

def Mech.rule_expanded_duplicate() -> T.RuleRef:
  T.RuleRef{"structure.expanded-duplicate", "1"}

def Mech.rule_route_edge() -> T.RuleRef:
  T.RuleRef{"reference.route-edge", "1"}

def Mech.rule_case_similar() -> T.RuleRef:
  T.RuleRef{"notation.case-similar", "1"}

# --- small helpers ---------------------------------------------------------
def Mech.inc_if(cond: Bool, n: Nat) -> Nat:
  match cond:
    case True{}:
      1n+n
    case False{}:
      n

def Mech.b2n(b: Bool) -> Nat:
  match b:
    case True{}:
      1n
    case False{}:
      0n

# --- accessors: RuleRef ----------------------------------------------------
def RuleRef.id(r: T.RuleRef) -> String:
  match r:
    case T.RuleRef{id, version}:
      id

def RuleRef.ver(r: T.RuleRef) -> String:
  match r:
    case T.RuleRef{id, version}:
      version

# --- accessors: Evidence ---------------------------------------------------
def Ev.kind_tag(k: T.EvidenceKind) -> String:
  match k:
    case T.EvProse{}:
      "prose"
    case T.EvHeading{}:
      "heading"
    case T.EvLink{}:
      "link"
    case T.EvTex{}:
      "tex"
    case T.EvTableCell{}:
      "table-cell"
    case T.EvCaption{}:
      "caption"
    case T.EvFigure{}:
      "figure"
    case T.EvDefinition{}:
      "definition"
    case T.EvSourcePattern{}:
      "source-pattern"

def Ev.canon(e: T.Evidence) -> String:
  match e:
    case T.Evidence{id, documentSha256, sourcePath, span, rawExcerpt, displayText, anchor, kind}:
      match span:
        case T.Span{start, end}:
          Ev.kind_tag(kind) ++ "|" ++ rawExcerpt ++ "|" ++ U32.show(start) ++ ":" ++ U32.show(end)

def Mech.canon_evs(evs: List<&2, T.Evidence>) -> String:
  match evs:
    case Nil{}:
      ""
    case Con{e, t}:
      Ev.canon(e) ++ "\n" ++ Mech.canon_evs(t)

# --- accessors: Block ------------------------------------------------------
def Blk.kind(b: T.Block) -> T.BlockKind:
  match b:
    case T.Block{blockId, kind, tagName, sectionAnchor, authoredId, headingLevel, ancestorSections, text, mapped, evidence, links, tex}:
      kind

def Blk.tag(b: T.Block) -> String:
  match b:
    case T.Block{blockId, kind, tagName, sectionAnchor, authoredId, headingLevel, ancestorSections, text, mapped, evidence, links, tex}:
      tagName

def Blk.level(b: T.Block) -> Maybe<&2, U32>:
  match b:
    case T.Block{blockId, kind, tagName, sectionAnchor, authoredId, headingLevel, ancestorSections, text, mapped, evidence, links, tex}:
      headingLevel

def Blk.text(b: T.Block) -> String:
  match b:
    case T.Block{blockId, kind, tagName, sectionAnchor, authoredId, headingLevel, ancestorSections, text, mapped, evidence, links, tex}:
      text

def Blk.evidence(b: T.Block) -> List<&2, T.Evidence>:
  match b:
    case T.Block{blockId, kind, tagName, sectionAnchor, authoredId, headingLevel, ancestorSections, text, mapped, evidence, links, tex}:
      evidence

def Blk.links(b: T.Block) -> List<&2, T.Link>:
  match b:
    case T.Block{blockId, kind, tagName, sectionAnchor, authoredId, headingLevel, ancestorSections, text, mapped, evidence, links, tex}:
      links

def Blk.authored(b: T.Block) -> Maybe<&2, String>:
  match b:
    case T.Block{blockId, kind, tagName, sectionAnchor, authoredId, headingLevel, ancestorSections, text, mapped, evidence, links, tex}:
      authoredId

def Lnk.fragment(l: T.Link) -> Maybe<&2, String>:
  match l:
    case T.Link{href, decodedFragment, targetId, evidenceId}:
      decodedFragment

def Blk.tex(b: T.Block) -> List<&2, T.Tex>:
  match b:
    case T.Block{blockId, kind, tagName, sectionAnchor, authoredId, headingLevel, ancestorSections, text, mapped, evidence, links, tex}:
      tex

def Tex.raw(x: T.Tex) -> String:
  match x:
    case T.Tex{raw, display, recognized, evidenceId}:
      raw

def Tex.recognized(x: T.Tex) -> Bool:
  match x:
    case T.Tex{raw, display, recognized, evidenceId}:
      recognized

def Mech.nonempty(s: String) -> Bool:
  Bool.not(String.is_empty(s))

def Blk.is_heading(k: T.BlockKind) -> Bool:
  match k:
    case T.BkHeading{}:
      True{}
    case T.BkProse{}:
      False{}
    case T.BkPre{}:
      False{}
    case T.BkMath{}:
      False{}
    case T.BkTable{}:
      False{}
    case T.BkFigure{}:
      False{}
    case T.BkDefinition{}:
      False{}
    case T.BkOther{}:
      False{}

def Blk.section(b: T.Block) -> String:
  match b:
    case T.Block{blockId, kind, tagName, sectionAnchor, authoredId, headingLevel, ancestorSections, text, mapped, evidence, links, tex}:
      sectionAnchor

def Blk.mapped(b: T.Block) -> Bool:
  match b:
    case T.Block{blockId, kind, tagName, sectionAnchor, authoredId, headingLevel, ancestorSections, text, mapped, evidence, links, tex}:
      mapped

def Blk.is_prose(k: T.BlockKind) -> Bool:
  match k:
    case T.BkHeading{}:
      False{}
    case T.BkProse{}:
      True{}
    case T.BkPre{}:
      False{}
    case T.BkMath{}:
      False{}
    case T.BkTable{}:
      False{}
    case T.BkFigure{}:
      False{}
    case T.BkDefinition{}:
      False{}
    case T.BkOther{}:
      False{}

def Blk.is_pre(k: T.BlockKind) -> Bool:
  match k:
    case T.BkHeading{}:
      False{}
    case T.BkProse{}:
      False{}
    case T.BkPre{}:
      True{}
    case T.BkMath{}:
      False{}
    case T.BkTable{}:
      False{}
    case T.BkFigure{}:
      False{}
    case T.BkDefinition{}:
      False{}
    case T.BkOther{}:
      False{}

# --- makeFinding -----------------------------------------------------------
def Mech.canon(+r: T.RuleRef, evs: List<&2, T.Evidence>) -> String:
  RuleRef.id(r) ++ "@" ++ RuleRef.ver(r) ++ "#" ++ Mech.canon_evs(evs)

def Mech.record_id(+rule: T.RuleRef, +fp: String) -> String:
  RuleRef.id(rule) ++ ":" ++ String.take(fp, 20n)

def Mech.finding(
  +rule: T.RuleRef,
  dim: T.Dimension,
  kind: T.FindingKind,
  title: String,
  message: String,
  +evs: List<&2, T.Evidence>,
) -> T.Finding:
  +fp = S.Sha256.hex(Mech.canon(rule, evs))
  recordId = Mech.record_id(rule, fp)
  T.Finding{recordId, rule, dim, T.Mechanical{}, kind, title, message, evs, fp, None{}}

# --- rule: structure.heading-depth ----------------------------------------
def Mech.hd_cmp(over: Bool, +v: U32, evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  match over:
    case False{}:
      Nil{}
    case True{}:
      [ Mech.finding(Mech.rule_heading_depth(), T.Structure{}, T.Candidate{},
          "Deep heading level",
          "Heading level " ++ U32.show(v) ++ " exceeds the advisory depth threshold.",
          evs) ]

def Mech.hd_lvl(+threshold: U32, lvl: Maybe<&2, U32>, evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  match lvl:
    case None{}:
      Nil{}
    case Some{+v}:
      Mech.hd_cmp(U32.is_gt(v, threshold), v, evs)

def Mech.hd_k(isH: Bool, threshold: U32, lvl: Maybe<&2, U32>, evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  match isH:
    case False{}:
      Nil{}
    case True{}:
      Mech.hd_lvl(threshold, lvl, evs)

def Mech.hd_one(+threshold: U32, +b: T.Block) -> List<&2, T.Finding>:
  Mech.hd_k(Blk.is_heading(Blk.kind(b)), threshold, Blk.level(b), Blk.evidence(b))

# --- rule: terminology.definition -----------------------------------------
def Mech.dfn_k(isDfn: Bool, term: String, evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  match isDfn:
    case False{}:
      Nil{}
    case True{}:
      [ Mech.finding(Mech.rule_definition(), T.Terminology{}, T.Observation{},
          "Explicit definition",
          "The term \"" ++ term ++ "\" is marked with an explicit dfn element.",
          evs) ]

def Mech.dfn_one(+b: T.Block) -> List<&2, T.Finding>:
  Mech.dfn_k(String.eq(String.to_lower(Blk.tag(b)), "dfn"), Blk.text(b), Blk.evidence(b))

# --- rule: source.escaped-pipe --------------------------------------------
# count "\|" occurrences by tracking the previous char code (single recursion)
def Mech.cep_go(s: String, prev: U32, acc: Nat) -> Nat:
  match s:
    case SNil{}:
      acc
    case SCon{c, t}:
      +code = Char.to_u32(c)
      Mech.cep_go(t, code, Mech.inc_if(Bool.and(U32.is_eq(prev, 92), U32.is_eq(code, 124)), acc))

def Mech.cep_count(s: String) -> Nat:
  Mech.cep_go(s, 0, 0n)

# count lines with >= 2 escaped pipes
def Mech.epl_go(lines: List<&2, String>) -> Nat:
  match lines:
    case Nil{}:
      0n
    case Con{l, t}:
      Mech.inc_if(Nat.is_ge(Mech.cep_count(l), 2n), Mech.epl_go(t))

def Mech.esc_pipe_lines(text: String) -> Nat:
  Mech.epl_go(String.lines(text))

def Mech.ep_k(hit: Bool, evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  match hit:
    case False{}:
      Nil{}
    case True{}:
      [ Mech.finding(Mech.rule_escaped_pipe(), T.SourceIntegrity{}, T.Candidate{},
          "Escaped-pipe tabular source candidate",
          "Multiple source text lines contain repeated escaped pipes resembling a serialized tabular row.",
          evs) ]

def Mech.ep_one(+b: T.Block) -> List<&2, T.Finding>:
  Mech.ep_k(Nat.is_ge(Mech.esc_pipe_lines(Blk.text(b)), 2n), Blk.evidence(b))

# --- rule: structure.heading-transition (pairwise consecutive headings) -----
# NOTE: the TS route-key guard (optionalAncestors) is omitted; the core Block
# model here has no optionalAncestors field. All headings are treated same-route.
def Mech.trans_cmp(skip: Bool, av: U32, bv: U32, ea: List<&2, T.Evidence>, eb: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  match skip:
    case False{}:
      Nil{}
    case True{}:
      [ Mech.finding(Mech.rule_heading_transition(), T.Structure{}, T.Candidate{},
          "Heading-level transition skips a level",
          "The heading transition from level " ++ U32.show(av) ++ " to " ++ U32.show(bv) ++ " skips a level.",
          List.append(&2, T.Evidence, ea, eb)) ]

def Mech.trans_lvls(la: Maybe<&2, U32>, lb: Maybe<&2, U32>, ea: List<&2, T.Evidence>, eb: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  match la:
    case None{}:
      Nil{}
    case Some{+av}:
      match lb:
        case None{}:
          Nil{}
        case Some{+bv}:
          Mech.trans_cmp(U32.is_gt(bv, U32.add(av, 1)), av, bv, ea, eb)

def Mech.trans_pair(+a: T.Block, +b: T.Block) -> List<&2, T.Finding>:
  Mech.trans_lvls(Blk.level(a), Blk.level(b), Blk.evidence(a), Blk.evidence(b))

# `rest` first so the shrinking arg precedes the carried previous heading `a`
def Mech.trans_go(rest: List<&2, T.Block>, a: T.Block) -> List<&2, T.Finding>:
  match rest:
    case Nil{}:
      Nil{}
    case Con{+b, r}:
      List.append(&2, T.Finding, Mech.trans_pair(a, b), Mech.trans_go(r, b))

def Mech.transitions(hs: List<&2, T.Block>) -> List<&2, T.Finding>:
  match hs:
    case Nil{}:
      Nil{}
    case Con{a, t}:
      Mech.trans_go(t, a)

def Mech.ho_put(isH: Bool, b: T.Block, rest: List<&2, T.Block>) -> List<&2, T.Block>:
  match isH:
    case True{}:
      b <> rest
    case False{}:
      rest

def Mech.headings_only(blocks: List<&2, T.Block>) -> List<&2, T.Block>:
  match blocks:
    case Nil{}:
      Nil{}
    case Con{+b, t}:
      Mech.ho_put(Blk.is_heading(Blk.kind(b)), b, Mech.headings_only(t))

# --- rule: reference.unresolved -------------------------------------------
# collect all authored ids across blocks (the resolvable-id set)
def Mech.prepend_id(a: Maybe<&2, String>, rest: List<&2, String>) -> List<&2, String>:
  match a:
    case None{}:
      rest
    case Some{v}:
      v <> rest

def Mech.collect_ids(blocks: List<&2, T.Block>) -> List<&2, String>:
  match blocks:
    case Nil{}:
      Nil{}
    case Con{b, t}:
      Mech.prepend_id(Blk.authored(b), Mech.collect_ids(t))

def Mech.unres_chk(missing: Bool, f: String, evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  match missing:
    case False{}:
      Nil{}
    case True{}:
      [ Mech.finding(Mech.rule_unresolved(), T.Reference{}, T.Observation{},
          "Unresolved internal fragment link",
          "The internal fragment \"" ++ f ++ "\" does not resolve to an authored ID.",
          evs) ]

def Mech.unres_frag(+ids: List<&2, String>, frag: Maybe<&2, String>, evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  match frag:
    case None{}:
      Nil{}
    case Some{+f}:
      Mech.unres_chk(Bool.not(List.contains(~String, ~String.eq, ids, f)), f, evs)

def Mech.unres_links(+ids: List<&2, String>, links: List<&2, T.Link>, +evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  match links:
    case Nil{}:
      Nil{}
    case Con{lk, t}:
      List.append(&2, T.Finding, Mech.unres_frag(ids, Lnk.fragment(lk), evs), Mech.unres_links(ids, t, evs))

def Mech.unresolved(+ids: List<&2, String>, +b: T.Block) -> List<&2, T.Finding>:
  Mech.unres_links(ids, Blk.links(b), Blk.evidence(b))

# --- rule: source.ascii-diagram (pre blocks with >=2 diagram features) ------
def Mech.lines_with_sub(lines: List<&2, String>, +sub: String) -> Nat:
  match lines:
    case Nil{}:
      0n
    case Con{l, t}:
      Mech.inc_if(String.contains(l, sub), Mech.lines_with_sub(t, sub))

def Mech.feat_vert(ls: List<&2, String>) -> Nat:
  Mech.b2n(Nat.is_ge(Mech.lines_with_sub(ls, "|"), 2n))

def Mech.feat_arrow(+ls: List<&2, String>) -> Nat:
  Mech.b2n(Bool.or(
    Nat.is_ge(Mech.lines_with_sub(ls, "->"), 1n),
    Nat.is_ge(Mech.lines_with_sub(ls, "<-"), 1n)))

def Mech.feat_box(+ls: List<&2, String>) -> Nat:
  Mech.b2n(Bool.or(
    Nat.is_ge(Mech.lines_with_sub(ls, "+-"), 1n),
    Nat.is_ge(Mech.lines_with_sub(ls, "-+"), 1n)))

def Mech.feat_dash(ls: List<&2, String>) -> Nat:
  Mech.b2n(Nat.is_ge(Mech.lines_with_sub(ls, "---"), 1n))

def Mech.ascii_features(text: String) -> Nat:
  +ls = String.lines(text)
  Nat.add(Mech.feat_vert(ls), Nat.add(Mech.feat_arrow(ls), Nat.add(Mech.feat_box(ls), Mech.feat_dash(ls))))

def Mech.ad_f(hit: Bool, evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  match hit:
    case False{}:
      Nil{}
    case True{}:
      [ Mech.finding(Mech.rule_ascii_diagram(), T.SourceIntegrity{}, T.Candidate{},
          "ASCII diagram source candidate",
          "A preformatted block has multiple independent diagram-like source features.",
          evs) ]

def Mech.ad_k(isPre: Bool, text: String, evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  match isPre:
    case False{}:
      Nil{}
    case True{}:
      Mech.ad_f(Nat.is_ge(Mech.ascii_features(text), 2n), evs)

def Mech.ad_one(+b: T.Block) -> List<&2, T.Finding>:
  Mech.ad_k(Blk.is_pre(Blk.kind(b)), Blk.text(b), Blk.evidence(b))

# --- rule: structure.duplicate-id -----------------------------------------
# one observation per authored id that occurs on >= 2 blocks.
def Mech.count_str(xs: List<&2, String>, +x: String) -> Nat:
  match xs:
    case Nil{}:
      0n
    case Con{h, t}:
      Mech.inc_if(String.eq(h, x), Mech.count_str(t, x))

def Mech.nub_put(present: Bool, h: String, acc: List<&2, String>) -> List<&2, String>:
  match present:
    case True{}:
      acc
    case False{}:
      h <> acc

def Mech.nub_go(xs: List<&2, String>, +acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      List.reverse(&2, String, acc)
    case Con{+h, t}:
      Mech.nub_go(t, Mech.nub_put(List.contains(~String, ~String.eq, acc, h), h, acc))

def Mech.nub(xs: List<&2, String>) -> List<&2, String>:
  Mech.nub_go(xs, Nil{})

def Mech.maybe_eq(m: Maybe<&2, String>, id: String) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{v}:
      String.eq(v, id)

def Mech.authored_eq(b: T.Block, id: String) -> Bool:
  Mech.maybe_eq(Blk.authored(b), id)

def Mech.ev_join(keep: Bool, evs: List<&2, T.Evidence>, rest: List<&2, T.Evidence>) -> List<&2, T.Evidence>:
  match keep:
    case True{}:
      List.append(&2, T.Evidence, evs, rest)
    case False{}:
      rest

# evidence of every block whose authored id equals `id`
def Mech.ev_for_id(blocks: List<&2, T.Block>, +id: String) -> List<&2, T.Evidence>:
  match blocks:
    case Nil{}:
      Nil{}
    case Con{+b, t}:
      Mech.ev_join(Mech.authored_eq(b, id), Blk.evidence(b), Mech.ev_for_id(t, id))

def Mech.dup_emit(dup: Bool, +id: String, evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  match dup:
    case False{}:
      Nil{}
    case True{}:
      [ Mech.finding(Mech.rule_duplicate_id(), T.Structure{}, T.Observation{},
          "Duplicate authored ID",
          "The authored ID \"" ++ id ++ "\" occurs on multiple mapped blocks.",
          evs) ]

def Mech.dup_one(+all_ids: List<&2, String>, +blocks: List<&2, T.Block>, +id: String) -> List<&2, T.Finding>:
  Mech.dup_emit(Nat.is_ge(Mech.count_str(all_ids, id), 2n), id, Mech.ev_for_id(blocks, id))

def Mech.dup_go(distinct: List<&2, String>, +all_ids: List<&2, String>, +blocks: List<&2, T.Block>) -> List<&2, T.Finding>:
  match distinct:
    case Nil{}:
      Nil{}
    case Con{id, t}:
      List.append(&2, T.Finding, Mech.dup_one(all_ids, blocks, id), Mech.dup_go(t, all_ids, blocks))

def Mech.duplicate_ids(+all_ids: List<&2, String>, +blocks: List<&2, T.Block>) -> List<&2, T.Finding>:
  Mech.dup_go(Mech.nub(all_ids), all_ids, blocks)

# --- text metrics (deterministic; ASCII-oriented like the rest of v1) -------
# word = maximal run of alphabetic chars: count non-alpha -> alpha transitions
def Mech.wc_go(s: String, prev_alpha: Bool, acc: Nat) -> Nat:
  match s:
    case SNil{}:
      acc
    case SCon{c, t}:
      +isa = Char.is_alpha(c)
      Mech.wc_go(t, isa, Mech.inc_if(Bool.and(isa, Bool.not(prev_alpha)), acc))

def Mech.word_count(s: String) -> Nat:
  Mech.wc_go(s, False{}, 0n)

# character = alphanumeric char
def Mech.cc_go(s: String, acc: Nat) -> Nat:
  match s:
    case SNil{}:
      acc
    case SCon{+c, t}:
      Mech.cc_go(t, Mech.inc_if(Bool.or(Char.is_alpha(c), Char.is_digit(c)), acc))

def Mech.char_count(s: String) -> Nat:
  Mech.cc_go(s, 0n)

# sentence boundary = a terminator (. ! ?) followed by space or end-of-string
def Mech.is_term(+code: U32) -> Bool:
  Bool.or(U32.is_eq(code, 46), Bool.or(U32.is_eq(code, 33), U32.is_eq(code, 63)))

def Mech.sc_go(s: String, prev: U32, acc: Nat) -> Nat:
  match s:
    case SNil{}:
      Mech.inc_if(Mech.is_term(prev), acc)
    case SCon{+c, t}:
      Mech.sc_go(t, Char.to_u32(c), Mech.inc_if(Bool.and(Mech.is_term(prev), Char.is_space(c)), acc))

def Mech.sentence_count(s: String) -> Nat:
  Mech.sc_go(s, 0, 0n)

# --- section helpers -------------------------------------------------------
def Mech.in_section(b: T.Block, id: String) -> Bool:
  String.eq(Blk.section(b), id)

def Mech.spt_put(keep: Bool, txt: String, rest: String) -> String:
  match keep:
    case True{}:
      txt ++ "\n" ++ rest
    case False{}:
      rest

# join the text of mapped prose blocks in a section, separated by newlines
def Mech.sec_prose_text(blocks: List<&2, T.Block>, +sec: String) -> String:
  match blocks:
    case Nil{}:
      ""
    case Con{+b, t}:
      Mech.spt_put(
        Bool.and(Mech.in_section(b, sec), Bool.and(Blk.is_prose(Blk.kind(b)), Blk.mapped(b))),
        Blk.text(b), Mech.sec_prose_text(t, sec))

# evidence of mapped prose blocks in a section
def Mech.sec_prose_ev(blocks: List<&2, T.Block>, +sec: String) -> List<&2, T.Evidence>:
  match blocks:
    case Nil{}:
      Nil{}
    case Con{+b, t}:
      Mech.ev_join(
        Bool.and(Mech.in_section(b, sec), Bool.and(Blk.is_prose(Blk.kind(b)), Blk.mapped(b))),
        Blk.evidence(b), Mech.sec_prose_ev(t, sec))

# distinct section anchors, in first-seen order
def Mech.all_sections(blocks: List<&2, T.Block>) -> List<&2, String>:
  match blocks:
    case Nil{}:
      Nil{}
    case Con{b, t}:
      Blk.section(b) <> Mech.all_sections(t)

def Mech.section_ids(blocks: List<&2, T.Block>) -> List<&2, String>:
  Mech.nub(Mech.all_sections(blocks))

# --- signed centi (hundredths) display for ARI -----------------------------
def Mech.pad2_if(small: Bool, n: Nat) -> String:
  match small:
    case True{}:
      "0" ++ Nat.show(n)
    case False{}:
      Nat.show(n)

def Mech.pad2(+n: Nat) -> String:
  Mech.pad2_if(Nat.is_lt(n, 10n), n)

def Mech.psnd_nat(p: Nat & Nat) -> Nat:
  (q, r) = p
  r

def Mech.nmod100(mag: Nat) -> Nat:
  Mech.psnd_nat(Nat.divmod(mag, 100n))

def Mech.sign_str(neg: Bool) -> String:
  match neg:
    case True{}:
      "-"
    case False{}:
      ""

def Mech.show_centi(neg: Bool, +mag: Nat) -> String:
  Mech.sign_str(neg) ++ Nat.show(Nat.div(mag, 100n)) ++ "." ++ Mech.pad2(Mech.nmod100(mag))

# --- rule: formula.ari (per section) ---------------------------------------
# ari*100 = 471*chars/words + 50*words/sentences - 2143 (deterministic integer
# fixed-point; the TS version uses float 4.71/0.5/21.43).
def Mech.ari_show_if(pos: Bool, +a: Nat) -> String:
  match pos:
    case True{}:
      Mech.show_centi(False{}, Nat.sub(a, 2143n))
    case False{}:
      Mech.show_centi(True{}, Nat.sub(2143n, a))

def Mech.ari_str(pos: Bool, +a: Nat, evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  [ Mech.finding(Mech.rule_ari(), T.Formula{}, T.Observation{},
      "Automated Readability Index",
      "Eligible English prose has an Automated Readability Index of " ++ Mech.ari_show_if(pos, a) ++ ".",
      evs) ]

def Mech.ari_emit(+a: Nat, evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  Mech.ari_str(Nat.is_ge(a, 2143n), a, evs)

def Mech.ari_value_x100(chars: Nat, +words: Nat, sentences: Nat) -> Nat:
  Nat.add(Nat.div(Nat.mul(471n, chars), words), Nat.div(Nat.mul(50n, words), sentences))

def Mech.ari_gate(ok: Bool, +words: Nat, +sentences: Nat, +chars: Nat, evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  match ok:
    case False{}:
      Nil{}
    case True{}:
      Mech.ari_emit(Mech.ari_value_x100(chars, words, sentences), evs)

# eligibility: words >= min_w and sentences >= min_s (English assumed for v1)
def Mech.ari_eligible(min_w: Nat, min_s: Nat, +words: Nat, +sentences: Nat, chars: Nat, evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  Mech.ari_gate(
    Bool.and(Nat.is_ge(words, min_w), Nat.is_ge(sentences, min_s)),
    words, sentences, chars, evs)

def Mech.ari_section(+blocks: List<&2, T.Block>, +sec: String, min_w: Nat, min_s: Nat) -> List<&2, T.Finding>:
  +text = Mech.sec_prose_text(blocks, sec)
  Mech.ari_eligible(min_w, min_s,
    Mech.word_count(text), Mech.sentence_count(text), Mech.char_count(text),
    Mech.sec_prose_ev(blocks, sec))

def Mech.ari_go(sections: List<&2, String>, +blocks: List<&2, T.Block>, +min_w: Nat, +min_s: Nat) -> List<&2, T.Finding>:
  match sections:
    case Nil{}:
      Nil{}
    case Con{sec, t}:
      List.append(&2, T.Finding, Mech.ari_section(blocks, sec, min_w, min_s), Mech.ari_go(t, blocks, min_w, min_s))

def Mech.ari_all(+blocks: List<&2, T.Block>, +min_w: Nat, +min_s: Nat) -> List<&2, T.Finding>:
  Mech.ari_go(Mech.section_ids(blocks), blocks, min_w, min_s)

# --- rule: terminology.introduction-density (per section) ------------------
def Mech.is_term_tag(t: String) -> Bool:
  +tl = String.to_lower(t)
  Bool.or(String.eq(tl, "strong"), Bool.or(String.eq(tl, "b"), String.eq(tl, "dfn")))

def Mech.is_term_block(+b: T.Block, id: String) -> Bool:
  Bool.and(Mech.in_section(b, id), Bool.and(Mech.is_term_tag(Blk.tag(b)), Blk.mapped(b)))

def Mech.term_ev(blocks: List<&2, T.Block>, +sec: String) -> List<&2, T.Evidence>:
  match blocks:
    case Nil{}:
      Nil{}
    case Con{+b, t}:
      Mech.ev_join(Mech.is_term_block(b, sec), Blk.evidence(b), Mech.term_ev(t, sec))

def Mech.term_count(blocks: List<&2, T.Block>, +sec: String) -> Nat:
  match blocks:
    case Nil{}:
      0n
    case Con{+b, t}:
      Mech.inc_if(Mech.is_term_block(b, sec), Mech.term_count(t, sec))

def Mech.pw_of(keep: Bool, text: String) -> Nat:
  match keep:
    case True{}:
      Mech.word_count(text)
    case False{}:
      0n

# sum of prose words across mapped prose blocks in a section
def Mech.sec_prose_words(blocks: List<&2, T.Block>, +sec: String) -> Nat:
  match blocks:
    case Nil{}:
      0n
    case Con{+b, t}:
      Nat.add(Mech.pw_of(Bool.and(Mech.in_section(b, sec), Bool.and(Blk.is_prose(Blk.kind(b)), Blk.mapped(b))), Blk.text(b)), Mech.sec_prose_words(t, sec))

# Exact, unreduced source metric. A missing prose denominator remains
# unassessed rather than becoming a fabricated zero.
def Mech.terms_per_words(cnt: Nat, +pw: Nat) -> T.Metric:
  T.Metric.mk(cnt, pw)

def Mech.density_emit(fire: Bool, +cnt: Nat, +pw: Nat, evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  match fire:
    case False{}:
      Nil{}
    case True{}:
      +metric = Mech.terms_per_words(cnt, pw)
      [ Mech.finding(Mech.rule_term_density(), T.Terminology{}, T.Candidate{},
          "Dense explicit or bold term introduction",
          Nat.show(cnt) ++ " source-evidenced term blocks occur in " ++ Nat.show(pw) ++
            " prose words (termsPerWords=" ++ T.Metric.show(metric) ++ ").",
          evs) ]

def Mech.density_section(+blocks: List<&2, T.Block>, +sec: String, +min_terms: Nat) -> List<&2, T.Finding>:
  +cnt = Mech.term_count(blocks, sec)
  +pw  = Mech.sec_prose_words(blocks, sec)
  Mech.density_emit(
    Bool.and(Nat.is_ge(cnt, min_terms), Nat.is_gt(pw, 0n)),
    cnt, pw, Mech.term_ev(blocks, sec))

def Mech.density_go(sections: List<&2, String>, +blocks: List<&2, T.Block>, +min_terms: Nat) -> List<&2, T.Finding>:
  match sections:
    case Nil{}:
      Nil{}
    case Con{sec, t}:
      List.append(&2, T.Finding, Mech.density_section(blocks, sec, min_terms), Mech.density_go(t, blocks, min_terms))

def Mech.density_all(+blocks: List<&2, T.Block>, +min_terms: Nat) -> List<&2, T.Finding>:
  Mech.density_go(Mech.section_ids(blocks), blocks, min_terms)

# --- rule: structure.expanded-duplicate -----------------------------------
# normalized text = whitespace runs collapsed to single spaces, trimmed.
def Mech.sp_char(c: Char) -> Char:
  +cc = c
  Bool.pick(Char, Char.is_space(cc), Chr{32}, cc)

def Mech.spaced(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{c, t}:
      SCon{Mech.sp_char(c), Mech.spaced(t)}

def Mech.norm_ws(text: String) -> String:
  String.join(List.filter(~String, ~Mech.nonempty, String.split(Mech.spaced(text), ' ')), " ")

def Mech.dm_pick(hit: Bool, ev: List<&2, T.Evidence>, rec: Maybe<&2, List<&2, T.Evidence>>) -> Maybe<&2, List<&2, T.Evidence>>:
  match hit:
    case True{}:
      Some{ev}
    case False{}:
      rec

# evidence of the first later block whose normalized text equals `nt`
def Mech.dup_match(rest: List<&2, T.Block>, +nt: String) -> Maybe<&2, List<&2, T.Evidence>>:
  match rest:
    case Nil{}:
      None{}
    case Con{+b, t}:
      Mech.dm_pick(String.eq(Mech.norm_ws(Blk.text(b)), nt), Blk.evidence(b), Mech.dup_match(t, nt))

def Mech.exp_find(m: Maybe<&2, List<&2, T.Evidence>>, ev: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  match m:
    case None{}:
      Nil{}
    case Some{ev2}:
      [ Mech.finding(Mech.rule_expanded_duplicate(), T.Structure{}, T.Candidate{},
          "Expanded content duplicates a block",
          "Two source-mapped blocks share identical normalized prose.",
          List.append(&2, T.Evidence, ev, ev2)) ]

def Mech.exp_words(ok: Bool, nt: String, ev: List<&2, T.Evidence>, rest: List<&2, T.Block>) -> List<&2, T.Finding>:
  match ok:
    case False{}:
      Nil{}
    case True{}:
      Mech.exp_find(Mech.dup_match(rest, nt), ev)

def Mech.exp_one(+b: T.Block, rest: List<&2, T.Block>) -> List<&2, T.Finding>:
  +nt = Mech.norm_ws(Blk.text(b))
  Mech.exp_words(Nat.is_ge(Mech.word_count(nt), 12n), nt, Blk.evidence(b), rest)

def Mech.expanded_all(blocks: List<&2, T.Block>) -> List<&2, T.Finding>:
  match blocks:
    case Nil{}:
      Nil{}
    case Con{b, +rest}:
      List.append(&2, T.Finding, Mech.exp_one(b, rest), Mech.expanded_all(rest))

# --- rule: reference.route-edge (resolved internal link direction) ----------
def Mech.fi_pick(hit: Bool, i: Nat, rec: Maybe<&2, Nat>) -> Maybe<&2, Nat>:
  match hit:
    case True{}:
      Some{i}
    case False{}:
      rec

def Mech.find_index_go(all: List<&2, T.Block>, +f: String, +i: Nat) -> Maybe<&2, Nat>:
  match all:
    case Nil{}:
      None{}
    case Con{+b, t}:
      Mech.fi_pick(Mech.authored_eq(b, f), i, Mech.find_index_go(t, f, 1n+i))

def Mech.find_index(all: List<&2, T.Block>, +f: String) -> Maybe<&2, Nat>:
  Mech.find_index_go(all, f, 0n)

def Mech.dir_str(c: Cmp) -> String:
  match c:
    case LT{}:
      "forward"
    case EQ{}:
      "same"
    case GT{}:
      "backward"

def Mech.route_emit(c: Cmp, evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  [ Mech.finding(Mech.rule_route_edge(), T.Reference{}, T.Candidate{},
      "Directional internal link",
      "This resolved internal link points " ++ Mech.dir_str(c) ++ " in extracted document order.",
      evs) ]

def Mech.route_idx(srcI: Nat, tgt: Maybe<&2, Nat>, evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  match tgt:
    case None{}:
      Nil{}
    case Some{j}:
      Mech.route_emit(Nat.cmp(srcI, j), evs)

def Mech.route_one(i: Nat, all: List<&2, T.Block>, frag: Maybe<&2, String>, evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  match frag:
    case None{}:
      Nil{}
    case Some{f}:
      Mech.route_idx(i, Mech.find_index(all, f), evs)

def Mech.route_links(+i: Nat, +all: List<&2, T.Block>, links: List<&2, T.Link>, +evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  match links:
    case Nil{}:
      Nil{}
    case Con{lk, t}:
      List.append(&2, T.Finding, Mech.route_one(i, all, Lnk.fragment(lk), evs), Mech.route_links(i, all, t, evs))

def Mech.route_block(+i: Nat, +b: T.Block, +all: List<&2, T.Block>) -> List<&2, T.Finding>:
  Mech.route_links(i, all, Blk.links(b), Blk.evidence(b))

def Mech.route_go(rest: List<&2, T.Block>, +i: Nat, +all: List<&2, T.Block>) -> List<&2, T.Finding>:
  match rest:
    case Nil{}:
      Nil{}
    case Con{+b, t}:
      List.append(&2, T.Finding, Mech.route_block(i, b, all), Mech.route_go(t, 1n+i, all))

def Mech.route_all(+blocks: List<&2, T.Block>) -> List<&2, T.Finding>:
  Mech.route_go(blocks, 0n, blocks)

# --- rule: notation.case-similar (per section, command-aware) --------------
# Recognized TeX records prefer exact backslash commands (`\alpha`) as their
# spellings. Bare alphanumeric symbols remain the fallback for synthetic or
# plain TeX records that contain no commands.
type CmdSt is Data:
  CmdIdle{}
  CmdName{buf: String}

def Mech.tsp_char(c: Char) -> Char:
  +cc = c
  Bool.pick(Char, Bool.or(Char.is_alpha(cc), Char.is_digit(cc)), cc, Chr{32})

def Mech.spaced_alnum(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{c, t}:
      SCon{Mech.tsp_char(c), Mech.spaced_alnum(t)}

def Mech.alnum_words(raw: String) -> List<&2, String>:
  List.filter(~String, ~Mech.nonempty, String.split(Mech.spaced_alnum(raw), ' '))

def Mech.cmd_char(c: Char) -> Bool:
  U32.is_eq(Char.to_u32(c), 92)

def Mech.cmd_name_char(c: Char) -> Bool:
  Char.is_alpha(c)

def Mech.cmd_prepend(valid: Bool, +word: String, acc: List<&2, String>) -> List<&2, String>:
  match valid:
    case True{}:
      word <> acc
    case False{}:
      acc

def Mech.cmd_finish(st: CmdSt, +acc: List<&2, String>) -> List<&2, String>:
  match st:
    case CmdIdle{}:
      List.reverse(&2, String, acc)
    case CmdName{+buf}:
      List.reverse(&2, String, Mech.cmd_prepend(Nat.is_gt(String.length(buf), 1n), buf, acc))


def Mech.cmd_scan(s: String, st: CmdSt, +acc: List<&2, String>) -> List<&2, String>:
  match s:
    case SNil{}:
      Mech.cmd_finish(st, acc)
    case SCon{+c, +t}:
      match st:
        case CmdIdle{}:
          Bool.pick(List<&2, String>, Mech.cmd_char(c),
            Mech.cmd_scan(t, CmdName{"\\"}, acc),
            Mech.cmd_scan(t, CmdIdle{}, acc))
        case CmdName{+buf}:
          Bool.pick(List<&2, String>, Mech.cmd_name_char(c),
            Mech.cmd_scan(t, CmdName{buf ++ SCon{c, SNil{}}}, acc),
            Bool.pick(List<&2, String>, Mech.cmd_char(c),
              Mech.cmd_scan(t, CmdName{"\\"}, Mech.cmd_prepend(Nat.is_gt(String.length(buf), 1n), buf, acc)),
              Mech.cmd_scan(t, CmdIdle{}, Mech.cmd_prepend(Nat.is_gt(String.length(buf), 1n), buf, acc))))

def Mech.command_words(raw: String) -> List<&2, String>:
  Mech.cmd_scan(raw, CmdIdle{}, Nil{})

def Mech.tex_words_pick(empty: Bool, +commands: List<&2, String>, +raw: String) -> List<&2, String>:
  match empty:
    case True{}:
      Mech.alnum_words(raw)
    case False{}:
      commands

def Mech.one_tex_sp(rec: Bool, +raw: String) -> List<&2, String>:
  match rec:
    case False{}:
      Nil{}
    case True{}:
      +commands = Mech.command_words(raw)
      Mech.tex_words_pick(Nat.is_eq(List.length(&2, String, commands), 0n), commands, raw)

def Mech.tex_spellings(texs: List<&2, T.Tex>) -> List<&2, String>:
  match texs:
    case Nil{}:
      Nil{}
    case Con{+tx, t}:
      List.append(&2, String, Mech.one_tex_sp(Tex.recognized(tx), Tex.raw(tx)), Mech.tex_spellings(t))

def Mech.blk_tex_sp(inSec: Bool, texs: List<&2, T.Tex>) -> List<&2, String>:
  match inSec:
    case False{}:
      Nil{}
    case True{}:
      Mech.tex_spellings(texs)

def Mech.sec_tex_spellings(blocks: List<&2, T.Block>, +sec: String) -> List<&2, String>:
  match blocks:
    case Nil{}:
      Nil{}
    case Con{+b, t}:
      List.append(&2, String, Mech.blk_tex_sp(Mech.in_section(b, sec), Blk.tex(b)), Mech.sec_tex_spellings(t, sec))

def Mech.has_rec_tex(texs: List<&2, T.Tex>) -> Bool:
  match texs:
    case Nil{}:
      False{}
    case Con{tx, t}:
      Bool.or(Tex.recognized(tx), Mech.has_rec_tex(t))

def Mech.sec_tex_ev(blocks: List<&2, T.Block>, +sec: String) -> List<&2, T.Evidence>:
  match blocks:
    case Nil{}:
      Nil{}
    case Con{+b, t}:
      Mech.ev_join(Bool.and(Mech.in_section(b, sec), Mech.has_rec_tex(Blk.tex(b))), Blk.evidence(b), Mech.sec_tex_ev(t, sec))

def Mech.lowers(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{s, t}:
      String.to_lower(s) <> Mech.lowers(t)

def Mech.count_fold(sp: List<&2, String>, +fold: String) -> Nat:
  match sp:
    case Nil{}:
      0n
    case Con{s, t}:
      Mech.inc_if(String.eq(String.to_lower(s), fold), Mech.count_fold(t, fold))

def Mech.notation_emit(dup: Bool, evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  match dup:
    case False{}:
      Nil{}
    case True{}:
      [ Mech.finding(Mech.rule_case_similar(), T.Notation{}, T.Candidate{},
          "Case-similar TeX symbols",
          "Two or more TeX spellings differ only by case within this scope.",
          evs) ]

def Mech.notation_folds(folds: List<&2, String>, +distinct_sp: List<&2, String>, +evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  match folds:
    case Nil{}:
      Nil{}
    case Con{f, t}:
      List.append(&2, T.Finding,
        Mech.notation_emit(Nat.is_ge(Mech.count_fold(distinct_sp, f), 2n), evs),
        Mech.notation_folds(t, distinct_sp, evs))

def Mech.notation_check(sp: List<&2, String>, evs: List<&2, T.Evidence>) -> List<&2, T.Finding>:
  +distinct_sp = Mech.nub(sp)
  Mech.notation_folds(Mech.nub(Mech.lowers(distinct_sp)), distinct_sp, evs)

def Mech.notation_section(+blocks: List<&2, T.Block>, +sec: String) -> List<&2, T.Finding>:
  Mech.notation_check(Mech.sec_tex_spellings(blocks, sec), Mech.sec_tex_ev(blocks, sec))

def Mech.notation_go(sections: List<&2, String>, +blocks: List<&2, T.Block>) -> List<&2, T.Finding>:
  match sections:
    case Nil{}:
      Nil{}
    case Con{sec, t}:
      List.append(&2, T.Finding, Mech.notation_section(blocks, sec), Mech.notation_go(t, blocks))

def Mech.notation_all(+blocks: List<&2, T.Block>) -> List<&2, T.Finding>:
  Mech.notation_go(Mech.section_ids(blocks), blocks)

# --- driver ----------------------------------------------------------------
def Mech.block_rules(+threshold: U32, +ids: List<&2, String>, +b: T.Block) -> List<&2, T.Finding>:
  List.append(&2, T.Finding, Mech.hd_one(threshold, b),
    List.append(&2, T.Finding, Mech.dfn_one(b),
      List.append(&2, T.Finding, Mech.ep_one(b),
        List.append(&2, T.Finding, Mech.ad_one(b), Mech.unresolved(ids, b)))))

def Mech.per_block(+threshold: U32, +ids: List<&2, String>, blocks: List<&2, T.Block>) -> List<&2, T.Finding>:
  match blocks:
    case Nil{}:
      Nil{}
    case Con{b, t}:
      List.append(&2, T.Finding, Mech.block_rules(threshold, ids, b), Mech.per_block(threshold, ids, t))

# min_w / min_s: ARI eligibility (TS defaults 100 / 3). min_terms: density (TS default 3).
def Mech.analyze_cfg(+threshold: U32, min_w: Nat, min_s: Nat, min_terms: Nat, +blocks: List<&2, T.Block>) -> List<&2, T.Finding>:
  +ids = Mech.collect_ids(blocks)
  List.append(&2, T.Finding,
    Mech.transitions(Mech.headings_only(blocks)),
    List.append(&2, T.Finding,
      Mech.duplicate_ids(ids, blocks),
      List.append(&2, T.Finding,
        Mech.ari_all(blocks, min_w, min_s),
        List.append(&2, T.Finding,
          Mech.density_all(blocks, min_terms),
          List.append(&2, T.Finding,
            Mech.expanded_all(blocks),
            List.append(&2, T.Finding,
              Mech.route_all(blocks),
              List.append(&2, T.Finding,
                Mech.notation_all(blocks),
                Mech.per_block(threshold, ids, blocks))))))))

def Mech.analyze(+threshold: U32, +blocks: List<&2, T.Block>) -> List<&2, T.Finding>:
  Mech.analyze_cfg(threshold, 100n, 3n, 3n, blocks)
