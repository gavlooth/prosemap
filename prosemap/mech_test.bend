# Mechanical rules runtime test. Run: bend prosemap/mech_test.bend
import Base
import ./types.bend as T
import ./contracts.bend as C
import ./mechanical.bend as M

# a block with one evidence covering [0,len) of `src`
def mk_block(+id: String, kind: T.BlockKind, tag: String, level: Maybe<&2, U32>, +text: String) -> T.Block:
  anchor = {T.Anchor{"sec-1", None{}} : T.Anchor}
  ev = C.Evidence.mk("ev-" ++ id, "hash", "doc.html", 0, U32.from_nat(String.length(text)), text, anchor, T.EvProse{}, text)
  T.Block{id, kind, tag, "sec-1", None{}, level, [], text, True{}, [ev], [], []}

# a heading block carrying an authored id and one internal fragment link
def mk_link_block(+id: String, +authored: Maybe<&2, String>, +frag: String, +text: String) -> T.Block:
  anchor = {T.Anchor{"sec-1", None{}} : T.Anchor}
  ev = C.Evidence.mk("ev-" ++ id, "hash", "doc.html", 0, U32.from_nat(String.length(text)), text, anchor, T.EvLink{}, text)
  lk = {T.Link{"#" ++ frag, Some{frag}, None{}, "ev-lk"} : T.Link}
  T.Block{id, T.BkProse{}, "p", "sec-1", authored, None{}, [], text, True{}, [ev], [lk], []}

def show_finding(f: T.Finding) -> String:
  match f:
    case T.Finding{recordId, rule, dimension, origin, kind, title, message, evidence, evidenceFingerprint, severity}:
      "  - " ++ recordId ++ "  (" ++ title ++ ")"

def show_findings(fs: List<&2, T.Finding>) -> String:
  match fs:
    case Nil{}:
      "  (none)"
    case Con{f, t}:
      show_finding(f) ++ "\n" ++ show_findings(t)

def main() -> IO(Unit):
  # h5 heading (level 5 > threshold 4) -> heading-depth candidate
  b1 = mk_block("b1", T.BkHeading{}, "h5", Some{5}, "Deeply Nested Heading")
  # a normal h2 heading -> no finding
  b2 = mk_block("b2", T.BkHeading{}, "h2", Some{2}, "Normal Heading")
  # a dfn -> terminology.definition observation
  b3 = mk_block("b3", T.BkDefinition{}, "dfn", None{}, "monad")
  # a prose block with two lines each containing two escaped pipes -> escaped-pipe
  b4 = mk_block("b4", T.BkProse{}, "p", None{}, "a \\| b \\| c\nd \\| e \\| f")
  # an h6 right after b1 (h5): level jumps 5->6 (only +1, no skip) -> NO transition;
  # but b1(h5) then b5(h3)? transitions only fire on skips forward. Use h2->h5 skip:
  b6 = mk_block("b6", T.BkHeading{}, "h5", Some{5}, "Jumped Heading")
  # a pre block with box borders, arrows and verticals -> ascii-diagram
  b7 = mk_block("b7", T.BkPre{}, "pre", None{}, "+---+\n| A | -> | B |\n+---+")
  # a link to a fragment that has no authored id -> unresolved; b8 defines #intro
  b8 = mk_link_block("b8", Some{"intro"}, "missing-target", "see intro")
  # b9 reuses authored id "intro" -> structure.duplicate-id (intro on b8 and b9)
  b9 = mk_link_block("b9", Some{"intro"}, "intro", "intro again")
  # headings in doc order: b2(h2) then b1(h5) -> skip -> transition finding
  blocks = {[b2, b1, b3, b4, b6, b7, b8, b9] : List<&2, T.Block>}
  do IO<Unit>:
    IO.print("findings (threshold=4):")
    IO.print(show_findings(M.Mech.analyze(4, blocks)))
