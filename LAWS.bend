# prosemap laws — the human-authored, ambiguity-free specs the implementation
# must satisfy. Proven in PROOF.bend; `bend PROOF.bend` is the gate.
#
# This is the headline of the Bend port: prosemap's evidence-integrity contract
# (src/contracts.ts:304) stops being a runtime assert + prose and becomes a
# machine-checked law. More laws (gate soundness, comparison conservatism,
# determinism, surface exclusion) are added as their modules land.
import Base
import ./prosemap/types.bend as T
import ./prosemap/contracts.bend as C
import ./prosemap/cohesion.bend as Co
import ./prosemap/gate.bend as G
import ./prosemap/comparison.bend as Cmp
import ./prosemap/mechanical.bend as M

# LAW (construction integrity): the only sanctioned evidence constructor,
# Evidence.mk, records exactly the source slice it derived. No caller can make
# it store an excerpt that differs from [start, end) of the source.
law evidence_records_slice:
  for id: String
  for documentSha256: String
  for sourcePath: String
  for +start: U32
  for +end: U32
  for displayText: String
  for anchor: T.Anchor
  for kind: T.EvidenceKind
  for source: String
  { C.Evidence.raw(C.Evidence.mk(id, documentSha256, sourcePath, start, end, displayText, anchor, kind, source))
    == C.Str.slice(source, start, end) : String }

# LAW (full evidence integrity): evidence built by Evidence.mk always SATISFIES
# the integrity predicate against its own source and hash — not just records the
# slice, but passes re-verification. This is the headline invariant of prosemap
# (assertEvidenceIntegrity) as a machine-checked theorem.
law evidence_integrity_holds:
  for id: String
  for documentSha256: String
  for sourcePath: String
  for start: U32
  for end: U32
  for displayText: String
  for anchor: T.Anchor
  for kind: T.EvidenceKind
  for source: String
  { C.Evidence.integrity2(source, C.Evidence.mk(id, documentSha256, sourcePath, start, end, displayText, anchor, kind, source), documentSha256)
    == True{} : Bool }

# LAW (cohesion conservatism): with no tokens on either side, both metrics are
# Unassessed — the analyzer never fabricates a score from nothing.
law cohesion_empty_unassessed:
  { Co.Cohesion.compare({Nil{} : List<&2, String>}, {Nil{} : List<&2, String>})
    == Co.Cmp3{{Nil{} : List<&2, String>}, T.Unassessed{}, T.Unassessed{}} : Co.Cmp3 }

# LAW (metric conservatism, general): ANY metric with a zero denominator is
# Unassessed — the analyzer never fabricates a score from nothing, for every
# metric, not just the empty-token case.
law metric_zero_den_unassessed:
  for num: Nat
  { T.Metric.mk(num, 0n) == T.Unassessed{} : T.Metric }

# LAW (gate conservatism): a candidate run with no findings can never fail the
# gate, for any base run and any allowlist.
law empty_candidate_passes:
  for base: List<&2, T.Finding>
  for allow: List<&2, T.RuleRef>
  { G.Gate.run(base, {Nil{} : List<&2, T.Finding>}, allow)
    == G.GateRes{True{}, {Nil{} : List<&2, T.Finding>}} : G.GateRes }

# LAW (comparison conservatism): a rule+anchor group whose base and candidate
# have different cardinalities is entirely `unmatched` — never guessed into
# added/resolved regressions (ports comparison.ts:228).
law group_unequal_unmatched:
  for bs: List<&2, T.Finding>
  for cs: List<&2, T.Finding>
  { Cmp.Cmp.group_card3(False{}, bs, cs) == Cmp.Cmp.all_unmatched(bs, cs) : List<&2, T.CompRecord> }

# LAW (finding identity): every sanctioned mechanical finding ID starts with
# the ID of its rule. The constructor owns the prefix; callers cannot silently
# substitute an unrelated rule namespace.
law finding_record_id_prefix:
  for rule: T.RuleRef
  for fingerprint: String
  { String.starts_with(M.Mech.record_id(rule, fingerprint), M.RuleRef.id(rule))
    == True{} : Bool }
