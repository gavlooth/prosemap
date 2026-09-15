# comparison + gate runtime test. Run: bend bend/prosemap/gate_test.bend
import Base
import ./types.bend as T
import ./contracts.bend as C
import ./comparison.bend as Cmp
import ./gate.bend as G

# a minimal mechanical observation finding with a given recordId + rule
def mkf(+rid: String, rule: T.RuleRef, kind: T.FindingKind) -> T.Finding:
  ev = C.Evidence.mk("e", "h", "d", 0, 1, "x", T.Anchor{"root", None{}}, T.EvProse{}, "xyz")
  T.Finding{rid, rule, T.Reference{}, T.Mechanical{}, kind, "t", "m", [ev], "fp", None{}}

def sb(b: Bool) -> String:
  match b:
    case True{}:
      "true"
    case False{}:
      "false"

def show(g: G.GateRes) -> String:
  match g:
    case G.GateRes{passed, violations}:
      "passed=" ++ sb(passed) ++ " violations=" ++ Nat.show(List.length(&2, T.Finding, violations))

def main() -> IO(Unit):
  # base run: one unresolved observation
  base = {[ mkf("reference.unresolved:aaa", T.RuleRef{"reference.unresolved","1"}, T.Observation{}) ] : List<&2, T.Finding>}
  # candidate: keeps the old one, ADDS a new unresolved observation + a non-eligible candidate
  +cand = {[ mkf("reference.unresolved:aaa", T.RuleRef{"reference.unresolved","1"}, T.Observation{}),
            mkf("reference.unresolved:bbb", T.RuleRef{"reference.unresolved","1"}, T.Observation{}),
            mkf("structure.heading-depth:ccc", T.RuleRef{"structure.heading-depth","1"}, T.Candidate{}) ] : List<&2, T.Finding>}
  allow = {[ T.RuleRef{"reference.unresolved", "1"} ] : List<&2, T.RuleRef>}
  do IO<Unit>:
    # comparison: 1 persisting + 1 added(unresolved) + 1 added(heading) ; 0 resolved
    IO.print("records = " ++ Nat.show(List.length(&2, T.CompRecord, Cmp.Cmp.compare(base, cand))))
    # gate: the added allowlisted unresolved observation is a violation -> fail
    IO.print(show(G.Gate.run(
      {[ mkf("reference.unresolved:aaa", T.RuleRef{"reference.unresolved","1"}, T.Observation{}) ] : List<&2, T.Finding>},
      cand, allow)))
