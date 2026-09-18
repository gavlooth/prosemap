# Finding comparison — recordId matching plus conservative rule/anchor grouping.
#
# v1 matches findings by recordId (which is `<rule.id>:<evidenceFingerprint[:20]>`,
# so it already encodes rule + evidence). Outcomes: persisting (in both), added
# (candidate only), resolved (base only). The full rule+anchor grouping with
# changed/unmatched ambiguity handling from the TS is a documented refinement;
# recordId matching is safe for the gate (which only acts on `added`).
import Base
import ./types.bend as T

# --- Finding accessors -----------------------------------------------------
def Fin.recordId(f: T.Finding) -> String:
  match f:
    case T.Finding{recordId, rule, dimension, origin, kind, title, message, evidence, evidenceFingerprint, severity}:
      recordId

def Fin.rule(f: T.Finding) -> T.RuleRef:
  match f:
    case T.Finding{recordId, rule, dimension, origin, kind, title, message, evidence, evidenceFingerprint, severity}:
      rule

def Fin.origin(f: T.Finding) -> T.Origin:
  match f:
    case T.Finding{recordId, rule, dimension, origin, kind, title, message, evidence, evidenceFingerprint, severity}:
      origin

def Fin.kind(f: T.Finding) -> T.FindingKind:
  match f:
    case T.Finding{recordId, rule, dimension, origin, kind, title, message, evidence, evidenceFingerprint, severity}:
      kind

# any finding in `fs` whose recordId equals `rid`
def Cmp.has_record(fs: List<&2, T.Finding>, +rid: String) -> Bool:
  match fs:
    case Nil{}:
      False{}
    case Con{f, t}:
      Bool.or(String.eq(Fin.recordId(f), rid), Cmp.has_record(t, rid))

# --- outcomes --------------------------------------------------------------
def Cmp.ap_rec(inBase: Bool, +rid: String) -> T.CompRecord:
  match inBase:
    case True{}:
      T.CompRecord{T.Persisting{}, None{}, Some{rid}, None{}}
    case False{}:
      T.CompRecord{T.Added{}, None{}, Some{rid}, None{}}

def Cmp.ap(cands: List<&2, T.Finding>, +base: List<&2, T.Finding>) -> List<&2, T.CompRecord>:
  match cands:
    case Nil{}:
      Nil{}
    case Con{c, t}:
      +rid = Fin.recordId(c)
      List.append(&2, T.CompRecord, [ Cmp.ap_rec(Cmp.has_record(base, rid), rid) ], Cmp.ap(t, base))

def Cmp.res_one(resolved: Bool, +rid: String) -> List<&2, T.CompRecord>:
  match resolved:
    case True{}:
      [ T.CompRecord{T.Resolved{}, Some{rid}, None{}, None{}} ]
    case False{}:
      Nil{}

def Cmp.res(base: List<&2, T.Finding>, +cand: List<&2, T.Finding>) -> List<&2, T.CompRecord>:
  match base:
    case Nil{}:
      Nil{}
    case Con{b, t}:
      +rid = Fin.recordId(b)
      List.append(&2, T.CompRecord, Cmp.res_one(Bool.not(Cmp.has_record(cand, rid)), rid), Cmp.res(t, cand))

def Cmp.compare(+base: List<&2, T.Finding>, +cand: List<&2, T.Finding>) -> List<&2, T.CompRecord>:
  List.append(&2, T.CompRecord, Cmp.ap(cand, base), Cmp.res(base, cand))

# ===========================================================================
# compare2: rule + anchor-signature grouping with conservative `unmatched`
# (ports the ambiguity handling of comparison.ts:207-294). Within a group of
# findings sharing (rule, anchor signature): unequal cardinality or leftover
# ambiguity yields `unmatched`, never a guessed added/resolved.
# ===========================================================================

# --- more accessors --------------------------------------------------------
def Fin.fp(f: T.Finding) -> String:
  match f:
    case T.Finding{recordId, rule, dimension, origin, kind, title, message, evidence, evidenceFingerprint, severity}:
      evidenceFingerprint

def Fin.evidence(f: T.Finding) -> List<&2, T.Evidence>:
  match f:
    case T.Finding{recordId, rule, dimension, origin, kind, title, message, evidence, evidenceFingerprint, severity}:
      evidence

def Ev.section(e: T.Evidence) -> String:
  match e:
    case T.Evidence{id, documentSha256, sourcePath, span, rawExcerpt, displayText, anchor, kind}:
      match anchor:
        case T.Anchor{section, block}:
          section

def Cmp.ruleid(r: T.RuleRef) -> String:
  match r:
    case T.RuleRef{id, version}:
      id ++ "@" ++ version

# --- small list utilities (local, string) ----------------------------------
def Cmp.nub_put(present: Bool, h: String, acc: List<&2, String>) -> List<&2, String>:
  match present:
    case True{}:
      acc
    case False{}:
      h <> acc

def Cmp.nub_go(xs: List<&2, String>, +acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      List.reverse(&2, String, acc)
    case Con{+h, t}:
      Cmp.nub_go(t, Cmp.nub_put(List.contains(~String, ~String.eq, acc, h), h, acc))

def Cmp.nub(xs: List<&2, String>) -> List<&2, String>:
  Cmp.nub_go(xs, Nil{})

def Cmp.ev_sections(evs: List<&2, T.Evidence>) -> List<&2, String>:
  match evs:
    case Nil{}:
      Nil{}
    case Con{e, t}:
      Ev.section(e) <> Cmp.ev_sections(t)

# a finding's group key: rule id/version + sorted distinct evidence anchors
def Fin.key(+f: T.Finding) -> String:
  Cmp.ruleid(Fin.rule(f)) ++ "#" ++ String.join(List.sort(~String, ~String.is_le, Cmp.nub(Cmp.ev_sections(Fin.evidence(f)))), ",")

def Cmp.all_keys(fs: List<&2, T.Finding>) -> List<&2, String>:
  match fs:
    case Nil{}:
      Nil{}
    case Con{f, t}:
      Fin.key(f) <> Cmp.all_keys(t)

# findings whose key equals k
def Cmp.with_key_put(hit: Bool, f: T.Finding, rest: List<&2, T.Finding>) -> List<&2, T.Finding>:
  match hit:
    case True{}:
      f <> rest
    case False{}:
      rest

def Cmp.with_key(fs: List<&2, T.Finding>, +k: String) -> List<&2, T.Finding>:
  match fs:
    case Nil{}:
      Nil{}
    case Con{+f, t}:
      Cmp.with_key_put(String.eq(Fin.key(f), k), f, Cmp.with_key(t, k))

# --- fingerprint lookups ----------------------------------------------------
def Cmp.fp_in(fs: List<&2, T.Finding>, +fp: String) -> Bool:
  match fs:
    case Nil{}:
      False{}
    case Con{f, t}:
      Bool.or(String.eq(Fin.fp(f), fp), Cmp.fp_in(t, fp))

def Cmp.ffp_pick(hit: Bool, rid: String, rec: Maybe<&2, String>) -> Maybe<&2, String>:
  match hit:
    case True{}:
      Some{rid}
    case False{}:
      rec

def Cmp.find_fp(fs: List<&2, T.Finding>, +fp: String) -> Maybe<&2, String>:
  match fs:
    case Nil{}:
      None{}
    case Con{+f, t}:
      Cmp.ffp_pick(String.eq(Fin.fp(f), fp), Fin.recordId(f), Cmp.find_fp(t, fp))

# --- per-group record builders ---------------------------------------------
def Cmp.all_added(cs: List<&2, T.Finding>) -> List<&2, T.CompRecord>:
  match cs:
    case Nil{}:
      Nil{}
    case Con{c, t}:
      T.CompRecord{T.Added{}, None{}, Some{Fin.recordId(c)}, None{}} <> Cmp.all_added(t)

def Cmp.all_resolved(bs: List<&2, T.Finding>) -> List<&2, T.CompRecord>:
  match bs:
    case Nil{}:
      Nil{}
    case Con{b, t}:
      T.CompRecord{T.Resolved{}, Some{Fin.recordId(b)}, None{}, None{}} <> Cmp.all_resolved(t)

def Cmp.unm_base(bs: List<&2, T.Finding>) -> List<&2, T.CompRecord>:
  match bs:
    case Nil{}:
      Nil{}
    case Con{b, t}:
      T.CompRecord{T.Unmatched{}, Some{Fin.recordId(b)}, None{}, Some{"ambiguous group"}} <> Cmp.unm_base(t)

def Cmp.unm_cand(cs: List<&2, T.Finding>) -> List<&2, T.CompRecord>:
  match cs:
    case Nil{}:
      Nil{}
    case Con{c, t}:
      T.CompRecord{T.Unmatched{}, None{}, Some{Fin.recordId(c)}, Some{"ambiguous group"}} <> Cmp.unm_cand(t)

def Cmp.all_unmatched(+bs: List<&2, T.Finding>, +cs: List<&2, T.Finding>) -> List<&2, T.CompRecord>:
  List.append(&2, T.CompRecord, Cmp.unm_base(bs), Cmp.unm_cand(cs))

# persisting pairs: base findings whose fingerprint also occurs in candidate.
# persist_rec is non-recursive so persist self-recurses (no mutual recursion).
def Cmp.persist_rec(m: Maybe<&2, String>, bid: String) -> List<&2, T.CompRecord>:
  match m:
    case None{}:
      Nil{}
    case Some{cid}:
      [ T.CompRecord{T.Persisting{}, Some{bid}, Some{cid}, None{}} ]

def Cmp.persist(baseG: List<&2, T.Finding>, +candG: List<&2, T.Finding>) -> List<&2, T.CompRecord>:
  match baseG:
    case Nil{}:
      Nil{}
    case Con{+b, t}:
      List.append(&2, T.CompRecord, Cmp.persist_rec(Cmp.find_fp(candG, Fin.fp(b)), Fin.recordId(b)), Cmp.persist(t, candG))

# leftover findings on one side that have no fingerprint match on the other
def Cmp.leftover_put(keep: Bool, f: T.Finding, rest: List<&2, T.Finding>) -> List<&2, T.Finding>:
  match keep:
    case True{}:
      f <> rest
    case False{}:
      rest

def Cmp.leftover(side: List<&2, T.Finding>, +other: List<&2, T.Finding>) -> List<&2, T.Finding>:
  match side:
    case Nil{}:
      Nil{}
    case Con{+f, t}:
      Cmp.leftover_put(Bool.not(Cmp.fp_in(other, Fin.fp(f))), f, Cmp.leftover(t, other))

# leftover reconciliation: 1-1 -> changed; 0-0 -> nothing; else -> unmatched
# (defined dependency-first: helpers precede callers)
def Cmp.head_id(fs: List<&2, T.Finding>) -> String:
  match fs:
    case Nil{}:
      ""
    case Con{f, t}:
      Fin.recordId(f)

def Cmp.changed_go(bid: String, cid: String) -> List<&2, T.CompRecord>:
  [ T.CompRecord{T.Changed{}, Some{bid}, Some{cid}, None{}} ]

def Cmp.changed(lb: List<&2, T.Finding>, lc: List<&2, T.Finding>) -> List<&2, T.CompRecord>:
  Cmp.changed_go(Cmp.head_id(lb), Cmp.head_id(lc))

def Cmp.reconcile_empty(empty: Bool, lb: List<&2, T.Finding>, lc: List<&2, T.Finding>) -> List<&2, T.CompRecord>:
  match empty:
    case True{}:
      Nil{}
    case False{}:
      Cmp.all_unmatched(lb, lc)

def Cmp.reconcile_pick(oneone: Bool, empty: Bool, +lb: List<&2, T.Finding>, +lc: List<&2, T.Finding>) -> List<&2, T.CompRecord>:
  match oneone:
    case True{}:
      Cmp.changed(lb, lc)
    case False{}:
      Cmp.reconcile_empty(empty, lb, lc)

def Cmp.reconcile_n(total: Nat, +lb: List<&2, T.Finding>, +lc: List<&2, T.Finding>) -> List<&2, T.CompRecord>:
  Cmp.reconcile_pick(
    Bool.and(Nat.is_eq(List.length(&2, T.Finding, lb), 1n), Nat.is_eq(List.length(&2, T.Finding, lc), 1n)),
    Nat.is_eq(total, 0n), lb, lc)

def Cmp.reconcile(+lb: List<&2, T.Finding>, +lc: List<&2, T.Finding>) -> List<&2, T.CompRecord>:
  Cmp.reconcile_n(Nat.add(List.length(&2, T.Finding, lb), List.length(&2, T.Finding, lc)), lb, lc)

# --- group dispatch (defined dependency-first) ------------------------------
def Cmp.group_card3(sameCard: Bool, +baseG: List<&2, T.Finding>, +candG: List<&2, T.Finding>) -> List<&2, T.CompRecord>:
  match sameCard:
    case False{}:
      Cmp.all_unmatched(baseG, candG)
    case True{}:
      List.append(&2, T.CompRecord,
        Cmp.persist(baseG, candG),
        Cmp.reconcile(Cmp.leftover(baseG, candG), Cmp.leftover(candG, baseG)))

def Cmp.group_card2(candEmpty: Bool, sameCard: Bool, +baseG: List<&2, T.Finding>, +candG: List<&2, T.Finding>) -> List<&2, T.CompRecord>:
  match candEmpty:
    case True{}:
      Cmp.all_resolved(baseG)
    case False{}:
      Cmp.group_card3(sameCard, baseG, candG)

def Cmp.group_card(baseEmpty: Bool, candEmpty: Bool, sameCard: Bool, +baseG: List<&2, T.Finding>, +candG: List<&2, T.Finding>) -> List<&2, T.CompRecord>:
  match baseEmpty:
    case True{}:
      Cmp.all_added(candG)
    case False{}:
      Cmp.group_card2(candEmpty, sameCard, baseG, candG)

def Cmp.group(+baseG: List<&2, T.Finding>, +candG: List<&2, T.Finding>) -> List<&2, T.CompRecord>:
  Cmp.group_card(
    Nat.is_eq(List.length(&2, T.Finding, baseG), 0n),
    Nat.is_eq(List.length(&2, T.Finding, candG), 0n),
    Nat.is_eq(List.length(&2, T.Finding, baseG), List.length(&2, T.Finding, candG)),
    baseG, candG)

# --- top level -------------------------------------------------------------
def Cmp.groups_go(keys: List<&2, String>, +base: List<&2, T.Finding>, +cand: List<&2, T.Finding>) -> List<&2, T.CompRecord>:
  match keys:
    case Nil{}:
      Nil{}
    case Con{+k, t}:
      List.append(&2, T.CompRecord,
        Cmp.group(Cmp.with_key(base, k), Cmp.with_key(cand, k)),
        Cmp.groups_go(t, base, cand))

def Cmp.compare2(+base: List<&2, T.Finding>, +cand: List<&2, T.Finding>) -> List<&2, T.CompRecord>:
  Cmp.groups_go(Cmp.nub(List.append(&2, String, Cmp.all_keys(base), Cmp.all_keys(cand))), base, cand)
