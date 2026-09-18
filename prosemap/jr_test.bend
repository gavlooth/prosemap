# JSON round-trip + gate over parsed findings. Run: bend prosemap/jr_test.bend
import Base
import ./types.bend as T
import ./json_read.bend as Jr
import ./comparison.bend as Cmp
import ./gate.bend as G

def sb(b: Bool) -> String:
  match b:
    case True{}:
      "true"
    case False{}:
      "false"

def show_f(+f: T.Finding) -> String:
  "recordId=" ++ Cmp.Fin.recordId(f) ++ " rule=" ++ Cmp.Cmp.ruleid(Cmp.Fin.rule(f))

def show_list(fs: List<&2, T.Finding>) -> String:
  match fs:
    case Nil{}:
      ""
    case Con{f, t}:
      "  " ++ show_f(f) ++ "\n" ++ show_list(t)

def show_gate(g: G.GateRes) -> String:
  match g:
    case G.GateRes{passed, violations}:
      "passed=" ++ sb(passed) ++ " violations=" ++ Nat.show(List.length(&2, T.Finding, violations))

def main() -> IO(Unit):
  # a base findings.jsonl (one unresolved observation) and a candidate that adds one
  +base = {"{\"recordId\":\"reference.unresolved:aaa\",\"rule\":\"reference.unresolved@1\",\"dimension\":\"reference\",\"kind\":\"observation\",\"title\":\"t\",\"message\":\"m\",\"evidenceFingerprint\":\"aaa\"}\n" : String}
  +cand = {"{\"recordId\":\"reference.unresolved:aaa\",\"rule\":\"reference.unresolved@1\",\"dimension\":\"reference\",\"kind\":\"observation\",\"title\":\"t\",\"message\":\"m\",\"evidenceFingerprint\":\"aaa\"}\n{\"recordId\":\"reference.unresolved:bbb\",\"rule\":\"reference.unresolved@1\",\"dimension\":\"reference\",\"kind\":\"observation\",\"title\":\"t\",\"message\":\"m\",\"evidenceFingerprint\":\"bbb\"}\n" : String}
  allow = {[ T.RuleRef{"reference.unresolved", "1"} ] : List<&2, T.RuleRef>}
  do IO<Unit>:
    IO.print("parsed candidate:")
    IO.print(show_list(Jr.Jr.parse(cand)))
    # gate over parsed base vs candidate: the newly-added allowlisted unresolved obs -> fail
    IO.print(show_gate(G.Gate.run(Jr.Jr.parse(base), Jr.Jr.parse(cand), allow)))
