# Minimal deterministic JSON emitter for on-disk artifacts (findings.jsonl).
# Emits one compact JSON object per finding. Reuses report.bend's enum strings
# and comparison.bend's Finding accessors.
import Base
import ./types.bend as T
import ./report.bend as Rep
import ./comparison.bend as Cmp

# --- string escaping -------------------------------------------------------
def Json.escc(+c: Char) -> String:
  +code = Char.to_u32(c)
  Bool.pick(String, U32.is_eq(code, 34), "\\\"",
    Bool.pick(String, U32.is_eq(code, 92), "\\\\",
      Bool.pick(String, U32.is_eq(code, 10), "\\n", SCon{c, SNil{}})))

def Json.esc(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{c, t}:
      Json.escc(c) ++ Json.esc(t)

def Json.str(s: String) -> String:
  "\"" ++ Json.esc(s) ++ "\""

# --- Finding field accessors (enum -> string via report.bend) ---------------
def Jf.dimension(f: T.Finding) -> String:
  match f:
    case T.Finding{recordId, rule, dimension, origin, kind, title, message, evidence, evidenceFingerprint, severity}:
      Rep.Rep.dim_str(dimension)

def Jf.kind(f: T.Finding) -> String:
  match f:
    case T.Finding{recordId, rule, dimension, origin, kind, title, message, evidence, evidenceFingerprint, severity}:
      Rep.Rep.kind_str(kind)

def Jf.title(f: T.Finding) -> String:
  match f:
    case T.Finding{recordId, rule, dimension, origin, kind, title, message, evidence, evidenceFingerprint, severity}:
      title

def Jf.message(f: T.Finding) -> String:
  match f:
    case T.Finding{recordId, rule, dimension, origin, kind, title, message, evidence, evidenceFingerprint, severity}:
      message

# --- one finding -> compact JSON object ------------------------------------
def Json.finding(+f: T.Finding) -> String:
  "{\"recordId\":" ++ Json.str(Cmp.Fin.recordId(f)) ++
  ",\"rule\":" ++ Json.str(Cmp.Cmp.ruleid(Cmp.Fin.rule(f))) ++
  ",\"dimension\":" ++ Json.str(Jf.dimension(f)) ++
  ",\"kind\":" ++ Json.str(Jf.kind(f)) ++
  ",\"title\":" ++ Json.str(Jf.title(f)) ++
  ",\"message\":" ++ Json.str(Jf.message(f)) ++
  ",\"evidenceFingerprint\":" ++ Json.str(Cmp.Fin.fp(f)) ++ "}"

def Json.findings_jsonl(fs: List<&2, T.Finding>) -> String:
  match fs:
    case Nil{}:
      ""
    case Con{f, t}:
      Json.finding(f) ++ "\n" ++ Json.findings_jsonl(t)

# --- run manifest ----------------------------------------------------------
def Json.enabled_rules() -> String:
  "[\"structure.heading-depth\",\"structure.heading-transition\",\"structure.duplicate-id\"," ++
  "\"structure.expanded-duplicate\",\"reference.unresolved\",\"reference.route-edge\"," ++
  "\"terminology.definition\",\"terminology.introduction-density\",\"notation.case-similar\"," ++
  "\"formula.ari\",\"source.escaped-pipe\",\"source.ascii-diagram\"]"

def Json.manifest(+sha: String, count: Nat) -> String:
  "{\"schemaVersion\":\"1\",\"toolVersion\":\"prosemap-bend/0.2\",\"format\":\"markdown\"," ++
  "\"sourceSha256\":" ++ Json.str(sha) ++
  ",\"findingCount\":" ++ Nat.show(count) ++
  ",\"enabledRules\":" ++ Json.enabled_rules() ++ "}\n"
