# Adjudicated-label and independent-review evaluator smoke.
# Run: bend prosemap/study_test.bend
import Base
import ./types.bend as T
import ./label_eval.bend as Le
import ./review_eval.bend as Re

def contextual(+rid: String) -> T.Finding:
  T.Finding{rid, T.RuleRef{"contextual.model", "1"}, T.Contextual{}, T.Model{}, T.Candidate{}, "candidate", "message", [], rid, None{}}

def main() -> IO(Unit):
  +labeled = {Le.Run{[
    Le.Observation{"doc.md", "-", ["reference.unresolved"], ["formula.ari"], ["reference.unresolved", "formula.ari"]}
  ], ""} : Le.Run}
  +findings = {[contextual("contextual:a"), contextual("contextual:b")] : List<&2, T.Finding>}
  +reviews = {[
    Re.Row{"contextual:a", "reviewer-a", "accepted"},
    Re.Row{"contextual:a", "reviewer-b", "accepted"},
    Re.Row{"contextual:b", "reviewer-a", "accepted"},
    Re.Row{"contextual:b", "reviewer-b", "rejected"}
  ] : List<&2, Re.Row>}
  do IO<Unit>:
    # Defect observed + neutral observation: no false positive or miss.
    IO.print(Le.Le.report(labeled))
    # Two reviewers per candidate; one consensus and one disagreement.
    IO.print(Re.Re.report(Re.Re.study(findings, reviews), ""))
