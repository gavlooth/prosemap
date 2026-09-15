# Report renderer — Bend port of the report.md rendering in src/report.ts.
# Pure String -> String: turns a finding list into a Markdown report. Kept
# deliberately simple for v1 (header, count, one entry per finding with its
# dimension, kind, recordId, and message).
import Base
import ./types.bend as T

def Rep.dim_str(d: T.Dimension) -> String:
  match d:
    case T.Structure{}:
      "structure"
    case T.Formula{}:
      "formula"
    case T.Cohesion{}:
      "cohesion"
    case T.Terminology{}:
      "terminology"
    case T.Notation{}:
      "notation"
    case T.Reference{}:
      "reference"
    case T.SourceIntegrity{}:
      "source-integrity"
    case T.Surface{}:
      "surface"
    case T.Contextual{}:
      "contextual"

def Rep.kind_str(k: T.FindingKind) -> String:
  match k:
    case T.Observation{}:
      "observation"
    case T.Candidate{}:
      "candidate"

def Rep.entry(f: T.Finding) -> String:
  match f:
    case T.Finding{recordId, rule, dimension, origin, kind, title, message, evidence, evidenceFingerprint, severity}:
      "## " ++ title ++ "\n\n" ++
      "- dimension: " ++ Rep.dim_str(dimension) ++ "\n" ++
      "- kind: " ++ Rep.kind_str(kind) ++ "\n" ++
      "- record: `" ++ recordId ++ "`\n\n" ++
      message ++ "\n\n"

def Rep.entries(fs: List<&2, T.Finding>) -> String:
  match fs:
    case Nil{}:
      ""
    case Con{f, t}:
      Rep.entry(f) ++ Rep.entries(t)

def Rep.count(fs: List<&2, T.Finding>) -> Nat:
  List.length(&2, T.Finding, fs)

def Rep.render(+fs: List<&2, T.Finding>) -> String:
  "# prosemap report\n\n" ++
  Nat.show(Rep.count(fs)) ++ " finding(s).\n\n" ++
  Rep.entries(fs)
