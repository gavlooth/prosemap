# prosemap proofs — discharge every law in LAWS.bend.
# Run `bend PROOF.bend`: it prints "All terms check." once every law holds.
import Base
import ./LAWS.bend as L
import ./prosemap/proof_lemmas.bend as PL
import ./prosemap/contracts.bend as C
import ./prosemap/mechanical.bend as M

# Evidence.mk unfolds to a literal whose rawExcerpt field is Str.slice(source,
# start, end); Evidence.raw projects that field. Both sides normalize to the
# same term, so reflexivity closes the goal.
def L.evidence_records_slice(id, documentSha256, sourcePath, start, end, displayText, anchor, kind, source):
  {==}

# Re-verification follows from structural string equality for the stored hash
# and the source slice derived by Evidence.mk.
def L.evidence_integrity_holds(id, documentSha256, sourcePath, start, end, displayText, anchor, kind, source):
  Equal.trans(
    Bool,
    Bool.and(C.Str.eq2(documentSha256, documentSha256), C.Str.eq2(C.Str.slice(source, start, end), C.Str.slice(source, start, end))),
    C.Str.eq2(C.Str.slice(source, start, end), C.Str.slice(source, start, end)),
    True{},
    Equal.cong(
      Bool,
      Bool,
      x => Bool.and(x, C.Str.eq2(C.Str.slice(source, start, end), C.Str.slice(source, start, end))),
      C.Str.eq2(documentSha256, documentSha256),
      True{},
      PL.PL.str_eq2_refl(documentSha256),
    ),
    PL.PL.str_eq2_refl(C.Str.slice(source, start, end)),
  )

# Both sides normalize to the same term (empty inputs compute an Unassessed
# metric), so reflexivity closes each goal.
def L.cohesion_empty_unassessed():
  {==}

# mk_metric(num, 0n) unfolds through is_eq(0,0)=True to Unassessed; num is dropped.
def L.metric_zero_den_unassessed(num):
  {==}

def L.empty_candidate_passes(base, allow):
  {==}

# group_card3 with sameCard=False takes the False branch = all_unmatched.
def L.group_unequal_unmatched(bs, cs):
  {==}

def L.finding_record_id_prefix(rule, fingerprint):
  PL.PL.starts_with_append(M.RuleRef.id(rule), ":" ++ String.take(fingerprint, 20n))
