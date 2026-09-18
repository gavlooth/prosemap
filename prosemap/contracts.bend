# Evidence integrity — the core prosemap invariant.
#
# The core invariant of prosemap: a finding's evidence must reproduce an exact
# slice of the source. Here it is a decidable predicate over BYTE offsets (see
# types.bend header for the UTF-16 -> byte-offset deviation), and `Evidence.mk`
# is the only sanctioned constructor: it *derives* rawExcerpt from the source
# slice, so evidence it builds satisfies the integrity predicate by construction.
# That construction fact is what LAWS.bend/PROOF.bend will prove.
import Base
import ./types.bend as T
import ./utf8.bend as Utf8

# slice(source, start, end): the substring at UTF-8 byte offsets [start, end).
def Str.slice(source: String, +start: U32, end: U32) -> String:
  Utf8.Utf8.slice(source, start, end)

# Field getters (used by laws/proofs and downstream modules).
def Evidence.raw(ev: T.Evidence) -> String:
  match ev:
    case T.Evidence{id, documentSha256, sourcePath, span, rawExcerpt, displayText, anchor, kind}:
      rawExcerpt

def Evidence.span_of(ev: T.Evidence) -> T.Span:
  match ev:
    case T.Evidence{id, documentSha256, sourcePath, span, rawExcerpt, displayText, anchor, kind}:
      span

# A structural string equality (equivalent to String.eq) whose reflexivity is
# provable by a simple char-list induction — see proof_lemmas.bend. Used by
# integrity2 so the FULL integrity law is machine-checkable.
def Str.eq2(a: String, b: String) -> Bool:
  match a b:
    case SNil{} SNil{}:
      True{}
    case SNil{} SCon{h, t}:
      False{}
    case SCon{h, t} SNil{}:
      False{}
    case SCon{h1, t1} SCon{h2, t2}:
      Bool.and(Char.is_eq(h1, h2), Str.eq2(t1, t2))

# The integrity predicate: hash matches AND the recorded excerpt equals the slice.
def Evidence.integrity(source: String, ev: T.Evidence, expected: String) -> Bool:
  match ev:
    case T.Evidence{id, documentSha256, sourcePath, span, rawExcerpt, displayText, anchor, kind}:
      match span:
        case T.Span{start, end}:
          String.eq(documentSha256, expected) && String.eq(Str.slice(source, start, end), rawExcerpt)

# integrity, over the provable structural equality Str.eq2 (see integrity law).
def Evidence.integrity2(source: String, ev: T.Evidence, expected: String) -> Bool:
  match ev:
    case T.Evidence{id, documentSha256, sourcePath, span, rawExcerpt, displayText, anchor, kind}:
      match span:
        case T.Span{start, end}:
          Bool.and(Str.eq2(documentSha256, expected), Str.eq2(Str.slice(source, start, end), rawExcerpt))

# The sanctioned constructor: rawExcerpt is derived from the source, never passed in.
# Fields are positional, in declaration order (see types.bend Evidence).
def Evidence.mk(
  id: String,
  documentSha256: String,
  sourcePath: String,
  +start: U32,
  +end: U32,
  displayText: String,
  anchor: T.Anchor,
  kind: T.EvidenceKind,
  source: String,
) -> T.Evidence:
  T.Evidence{
    id,
    documentSha256,
    sourcePath,
    T.Span{start, end},
    Str.slice(source, start, end),
    displayText,
    anchor,
    kind,
  }
