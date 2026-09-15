# Minimal JSON reader for findings.jsonl (the format json.bend emits).
# Not a general JSON parser — it extracts the known flat string fields by key,
# enough to reconstruct Findings for the gate/compare stages. Scanners are
# self-recursive (a helper recursing back would be mutual recursion).
import Base
import ./types.bend as T

# tail after the first occurrence of `needle` (fuel-bounded, self-recursive)
def Jr.after(fuel: Nat, +hay: String, +needle: String) -> Maybe<&2, String>:
  match fuel:
    case 0n:
      None{}
    case 1n+p:
      Bool.pick(Maybe<&2, String>, String.starts_with(hay, needle),
        Some{String.drop(hay, String.length(needle))},
        Jr.after(p, String.drop(hay, 1n), needle))

def Jr.until_quote(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{+c, t}:
      Bool.pick(String, U32.is_eq(Char.to_u32(c), 34), "", SCon{c, Jr.until_quote(t)})

def Jr.until_char(+ch: U32, s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{+c, t}:
      Bool.pick(String, U32.is_eq(Char.to_u32(c), ch), "", SCon{c, Jr.until_char(ch, t)})

def Jr.field_m(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      ""
    case Some{rest}:
      Jr.until_quote(rest)

# value of "key":"..." in a JSON object line
def Jr.field(+line: String, +key: String) -> String:
  Jr.field_m(Jr.after(String.length(line), line, "\"" ++ key ++ "\":\""))

# rule stored as "id@version"
def Jr.after_at_m(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      ""
    case Some{rest}:
      rest

def Jr.rule_of(+s: String) -> T.RuleRef:
  T.RuleRef{Jr.until_char(64, s), Jr.after_at_m(Jr.after(String.length(s), s, "@"))}

def Jr.parse_dim(+s: String) -> T.Dimension:
  Bool.pick(T.Dimension, String.eq(s, "structure"), T.Structure{},
    Bool.pick(T.Dimension, String.eq(s, "formula"), T.Formula{},
      Bool.pick(T.Dimension, String.eq(s, "cohesion"), T.Cohesion{},
        Bool.pick(T.Dimension, String.eq(s, "terminology"), T.Terminology{},
          Bool.pick(T.Dimension, String.eq(s, "notation"), T.Notation{},
            Bool.pick(T.Dimension, String.eq(s, "reference"), T.Reference{},
              Bool.pick(T.Dimension, String.eq(s, "source-integrity"), T.SourceIntegrity{},
                Bool.pick(T.Dimension, String.eq(s, "surface"), T.Surface{}, T.Contextual{}))))))))

def Jr.parse_kind(+s: String) -> T.FindingKind:
  Bool.pick(T.FindingKind, String.eq(s, "observation"), T.Observation{}, T.Candidate{})

# one JSONL line -> Finding (evidence omitted; not needed by gate/compare)
def Jr.finding(+line: String) -> T.Finding:
  T.Finding{
    Jr.field(line, "recordId"),
    Jr.rule_of(Jr.field(line, "rule")),
    Jr.parse_dim(Jr.field(line, "dimension")),
    T.Mechanical{},
    Jr.parse_kind(Jr.field(line, "kind")),
    Jr.field(line, "title"),
    Jr.field(line, "message"),
    Nil{},
    Jr.field(line, "evidenceFingerprint"),
    None{},
  }

# non-empty lines -> findings
def Jr.line_put(keep: Bool, l: String, rest: List<&2, T.Finding>) -> List<&2, T.Finding>:
  match keep:
    case True{}:
      Jr.finding(l) <> rest
    case False{}:
      rest

def Jr.lines_go(lines: List<&2, String>) -> List<&2, T.Finding>:
  match lines:
    case Nil{}:
      Nil{}
    case Con{+l, t}:
      Jr.line_put(Bool.not(String.is_empty(l)), l, Jr.lines_go(t))

def Jr.parse(content: String) -> List<&2, T.Finding>:
  Jr.lines_go(String.lines(content))
