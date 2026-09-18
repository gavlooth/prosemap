# ARI + density runtime test. Run: bend prosemap/mech_test2.bend
import Base
import ./types.bend as T
import ./contracts.bend as C
import ./mechanical.bend as M

def mk(+id: String, kind: T.BlockKind, tag: String, +sec: String, +text: String) -> T.Block:
  ev = C.Evidence.mk("ev-" ++ id, "hash", "doc.html", 0, U32.from_nat(String.length(text)), text, T.Anchor{sec, None{}}, T.EvProse{}, text)
  T.Block{id, kind, tag, sec, None{}, None{}, [], text, True{}, [ev], [], []}

def show_findings(fs: List<&2, T.Finding>) -> String:
  match fs:
    case Nil{}:
      ""
    case Con{f, t}:
      match f:
        case T.Finding{recordId, rule, dimension, origin, kind, title, message, evidence, evidenceFingerprint, severity}:
          "  - " ++ title ++ ": " ++ message ++ "\n" ++ show_findings(t)

def main() -> IO(Unit):
  # section with 3 dfn term blocks + prose -> introduction-density (min 3)
  d1 = mk("d1", T.BkDefinition{}, "dfn", "s1", "functor")
  d2 = mk("d2", T.BkDefinition{}, "dfn", "s1", "monad")
  d3 = mk("d3", T.BkDefinition{}, "dfn", "s1", "applicative")
  p1 = mk("p1", T.BkProse{}, "p", "s1", "A functor maps between categories. It has ten words here now.")
  # a low-word section: no ARI (fewer than 100 words), no density
  p2 = mk("p2", T.BkProse{}, "p", "s2", "Short.")
  # use a tiny ARI threshold to fire on p1: min_w=5, min_s=1, min_terms=3
  blocks = {[d1, d2, d3, p1, p2] : List<&2, T.Block>}
  do IO<Unit>:
    # low thresholds (min_w=5, min_s=1, min_terms=3) so ARI fires on s1 too
    IO.print("analyze_cfg(threshold=4, min_w=5, min_s=1, min_terms=3):")
    # Exact terminology metrics preserve source counts; no prose denominator is
    # explicitly unassessed rather than represented as zero.
    IO.print("termsPerWords assessed=" ++ T.Metric.show(M.Mech.terms_per_words(3n, 12n)))
    IO.print("termsPerWords zero-den=" ++ T.Metric.show(M.Mech.terms_per_words(3n, 0n)))
    IO.print(show_findings(M.Mech.analyze_cfg(4, 5n, 1n, 3n, blocks)))
