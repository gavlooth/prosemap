# CI gate — Bend port of the core of src/gate.ts.
#
# A gate violation is a NEWLY ADDED (candidate-only) finding that is a
# gate-eligible, allowlisted, mechanical observation. Everything else is
# advisory. passed = no violations. (The TS also refuses incomplete/incompatible
# comparisons; v1 assumes a comparable+complete run.)
#
# Gate-eligible rules mirror GATE_ELIGIBLE_RULES: reference.unresolved and
# structure.duplicate-id.
import Base
import ./types.bend as T
import ./comparison.bend as Cmp
import ./sha256.bend as S
import ./markdown.bend as Md
import ./mechanical.bend as M
import ./json.bend as J
import ./json_read.bend as Jr


type GateRes is Data:
  GateRes{passed: Bool, violations: List<&2, T.Finding>}
type ReplayRes is Data:
  ReplayRes{verified: Bool, gate: GateRes}

def ReplayRes.verified(r: ReplayRes) -> Bool:
  match r:
    case ReplayRes{verified, gate}:
      verified

def ReplayRes.gate(r: ReplayRes) -> GateRes:
  match r:
    case ReplayRes{verified, gate}:
      gate

# --- RuleRef helpers -------------------------------------------------------
def Gate.rid(r: T.RuleRef) -> String:
  match r:
    case T.RuleRef{id, version}:
      id

def Gate.rver(r: T.RuleRef) -> String:
  match r:
    case T.RuleRef{id, version}:
      version

def Gate.rule_eq(+a: T.RuleRef, +b: T.RuleRef) -> Bool:
  Bool.and(String.eq(Gate.rid(a), Gate.rid(b)), String.eq(Gate.rver(a), Gate.rver(b)))

def Gate.rule_in(rules: List<&2, T.RuleRef>, +r: T.RuleRef) -> Bool:
  match rules:
    case Nil{}:
      False{}
    case Con{x, t}:
      Bool.or(Gate.rule_eq(x, r), Gate.rule_in(t, r))

def Gate.eligible_rules() -> List<&2, T.RuleRef>:
  [ T.RuleRef{"reference.unresolved", "1"}, T.RuleRef{"structure.duplicate-id", "1"} ]

# --- violation predicate ---------------------------------------------------
def Gate.origin_mech(o: T.Origin) -> Bool:
  match o:
    case T.Mechanical{}:
      True{}
    case T.Model{}:
      False{}

def Gate.kind_obs(k: T.FindingKind) -> Bool:
  match k:
    case T.Observation{}:
      True{}
    case T.Candidate{}:
      False{}

def Gate.is_mech_obs(+f: T.Finding) -> Bool:
  Bool.and(Gate.origin_mech(Cmp.Fin.origin(f)), Gate.kind_obs(Cmp.Fin.kind(f)))

def Gate.is_violation(+f: T.Finding, +allow: List<&2, T.RuleRef>) -> Bool:
  Bool.and(Gate.is_mech_obs(f),
    Bool.and(Gate.rule_in(Gate.eligible_rules(), Cmp.Fin.rule(f)),
             Gate.rule_in(allow, Cmp.Fin.rule(f))))

# --- added findings (candidate not in base) --------------------------------
def Gate.added_put(keep: Bool, f: T.Finding, rest: List<&2, T.Finding>) -> List<&2, T.Finding>:
  match keep:
    case True{}:
      f <> rest
    case False{}:
      rest

def Gate.added(cand: List<&2, T.Finding>, +base: List<&2, T.Finding>) -> List<&2, T.Finding>:
  match cand:
    case Con{+c, t}:
      Gate.added_put(Bool.not(Cmp.Cmp.has_record(base, Cmp.Fin.recordId(c))), c, Gate.added(t, base))
    case Nil{}:
      Nil{}

# --- violations ------------------------------------------------------------
def Gate.viol_put(v: Bool, f: T.Finding, rest: List<&2, T.Finding>) -> List<&2, T.Finding>:
  match v:
    case True{}:
      f <> rest
    case False{}:
      rest

def Gate.viol(fs: List<&2, T.Finding>, +allow: List<&2, T.RuleRef>) -> List<&2, T.Finding>:
  match fs:
    case Nil{}:
      Nil{}
    case Con{+f, t}:
      Gate.viol_put(Gate.is_violation(f, allow), f, Gate.viol(t, allow))

def Gate.run(+base: List<&2, T.Finding>, +cand: List<&2, T.Finding>, +allow: List<&2, T.RuleRef>) -> GateRes:
  +vs = Gate.viol(Gate.added(cand, base), allow)
  GateRes{Nat.is_eq(List.length(&2, T.Finding, vs), 0n), vs}

# --- replay verification ---------------------------------------------------
# Stored findings are trustworthy only when they are byte-for-byte the canonical
# JSONL artifact regenerated from an independently selected Markdown source.
# The equality is deliberately lexical as well as semantic: Json.findings_jsonl
# is the canonical encoding, so whitespace, reordered records, omitted records,
# forged values, and output from an incompatible analyzer all fail closed.
def Gate.replay_artifact(+source: String) -> String:
  +sha = S.Sha256.hex(source)
  J.Json.findings_jsonl(M.Mech.analyze(4, Md.Md.parse(source, sha)))

def Gate.replay_ok(+source: String, +stored: String) -> Bool:
  String.eq(Gate.replay_artifact(source), stored)

def Gate.replay_apply(verified: Bool, +base: List<&2, T.Finding>, +cand: List<&2, T.Finding>, +allow: List<&2, T.RuleRef>) -> GateRes:
  match verified:
    case True{}:
      Gate.run(base, cand, allow)
    case False{}:
      GateRes{False{}, Nil{}}

def Gate.replay_parsed(verified: Bool, +baseStored: String, +candidateStored: String, +allow: List<&2, T.RuleRef>) -> GateRes:
  Gate.replay_apply(verified, Jr.Jr.parse(baseStored), Jr.Jr.parse(candidateStored), allow)

def Gate.replay_run(+baseSource: String, +baseStored: String, +candidateSource: String, +candidateStored: String, +allow: List<&2, T.RuleRef>) -> ReplayRes:
  +verified = Bool.and(Gate.replay_ok(baseSource, baseStored), Gate.replay_ok(candidateSource, candidateStored))
  ReplayRes{verified, Gate.replay_parsed(verified, baseStored, candidateStored, allow)}
