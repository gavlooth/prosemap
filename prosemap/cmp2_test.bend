# I4: compare2 conservatism. A rule+anchor group with unequal cardinality must
# yield only `unmatched` (never guessed added/resolved). Run: bend prosemap/cmp2_test.bend
import Base
import ./types.bend as T
import ./contracts.bend as C
import ./comparison.bend as Cmp

# finding sharing rule "r@1" and anchor "s1"; fp distinguishes members
def mkf(+rid: String, +fp: String) -> T.Finding:
  ev = C.Evidence.mk("e", "h", "d", 0, 1, "x", T.Anchor{"s1", None{}}, T.EvProse{}, "xyz")
  T.Finding{rid, T.RuleRef{"r", "1"}, T.Reference{}, T.Mechanical{}, T.Observation{}, "t", "m", [ev], fp, None{}}

def outc(o: T.Outcome) -> String:
  match o:
    case T.Added{}:
      "added"
    case T.Resolved{}:
      "resolved"
    case T.Persisting{}:
      "persisting"
    case T.Changed{}:
      "changed"
    case T.Unmatched{}:
      "unmatched"

def show(rs: List<&2, T.CompRecord>) -> String:
  match rs:
    case Nil{}:
      ""
    case Con{r, t}:
      match r:
        case T.CompRecord{outcome, baseRecordId, candidateRecordId, reason}:
          outc(outcome) ++ " " ++ show(t)

def main() -> IO(Unit):
  # base: 2 findings in group r@1#s1 ; candidate: 1 finding, same group, new fp
  base = {[ mkf("r:aaa", "fpA"), mkf("r:bbb", "fpB") ] : List<&2, T.Finding>}
  cand = {[ mkf("r:ccc", "fpC") ] : List<&2, T.Finding>}
  do IO<Unit>:
    # expect: all unmatched (2 base + 1 cand = 3 unmatched), no added/resolved
    IO.print("compare2: " ++ show(Cmp.Cmp.compare2(base, cand)))
