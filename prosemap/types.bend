# prosemap core data model (Bend port of src/contracts.ts).
#
# This is a faithful *core subset* of the Zod schema in src/contracts.ts,
# covering the shapes the deterministic pipeline (extract -> mechanical ->
# compare -> gate -> report) actually consumes. Advisory-only optional fields
# on Finding (readerDependencies, routeDependencies, intrinsicDifficulty, ...)
# and the contextual/surface/manifest records are added in later steps; they
# are intentionally omitted here to keep v1 checkable.
#
# DEVIATION FROM TS (see plan): source spans are BYTE offsets into the UTF-8
# source, not UTF-16 offsets. Bend strings are codepoint lists and file IO
# yields bytes, so byte offsets are the stable, unambiguous choice. The
# evidence-integrity invariant is preserved, just redefined over bytes.
import Base

# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

# finding.dimension
type Dimension is Data:
  Structure{}
  Formula{}
  Cohesion{}
  Terminology{}
  Notation{}
  Reference{}
  SourceIntegrity{}
  Surface{}
  Contextual{}

# finding.origin
type Origin is Data:
  Mechanical{}
  Model{}

# finding.kind
type FindingKind is Data:
  Observation{}
  Candidate{}

# finding.severity (optional -> Maybe<Severity>)
type Severity is Data:
  Low{}
  Medium{}
  High{}

# evidence.kind
type EvidenceKind is Data:
  EvProse{}
  EvHeading{}
  EvLink{}
  EvTex{}
  EvTableCell{}
  EvCaption{}
  EvFigure{}
  EvDefinition{}
  EvSourcePattern{}

# block.kind
type BlockKind is Data:
  BkHeading{}
  BkProse{}
  BkPre{}
  BkMath{}
  BkTable{}
  BkFigure{}
  BkDefinition{}
  BkOther{}

# comparison.outcome
type Outcome is Data:
  Added{}
  Resolved{}
  Persisting{}
  Changed{}
  Unmatched{}

# ---------------------------------------------------------------------------
# Exact metrics
# ---------------------------------------------------------------------------
# Metrics retain their original numerator and denominator: reducing fractions
# would discard the source counts that make a finding independently auditable.
type Metric is Data:
  Unassessed{}
  Assessed{num: Nat, den: Nat}

# A metric never invents a value for a zero denominator.
def Metric.mk.if(zero: Bool, num: Nat, den: Nat) -> Metric:
  match zero:
    case True{}:
      Unassessed{}
    case False{}:
      Assessed{num, den}

def Metric.mk(num: Nat, +den: Nat) -> Metric:
  Metric.mk.if(Nat.is_eq(den, 0n), num, den)

def Metric.show(m: Metric) -> String:
  match m:
    case Unassessed{}:
      "unassessed"
    case Assessed{num, den}:
      Nat.show(num) ++ "/" ++ Nat.show(den)

def Metric.numerator(m: Metric) -> Maybe<&2, Nat>:
  match m:
    case Unassessed{}:
      None{}
    case Assessed{num, den}:
      Some{num}

def Metric.denominator(m: Metric) -> Maybe<&2, Nat>:
  match m:
    case Unassessed{}:
      None{}
    case Assessed{num, den}:
      Some{den}

# ---------------------------------------------------------------------------
# Records
# ---------------------------------------------------------------------------

# ruleRefSchema
type RuleRef is Data:
  RuleRef{id: String, version: String}

# sourceSpanSchema, over UTF-8 byte offsets (see header note); invariant end > start
type Span is Data:
  Span{start: U32, end: U32}

# anchorRefSchema (blockAnchor optional -> Maybe)
type Anchor is Data:
  Anchor{section: String, block: Maybe<&2, String>}

# evidenceRefSchema (core subset)
type Evidence is Data:
  Evidence{
    id: String,
    documentSha256: String,
    sourcePath: String,
    span: Span,
    rawExcerpt: String,
    displayText: String,
    anchor: Anchor,
    kind: EvidenceKind,
  }

# linkRecordSchema (core subset)
type Link is Data:
  Link{
    href: String,
    decodedFragment: Maybe<&2, String>,
    targetId: Maybe<&2, String>,
    evidenceId: String,
  }

# texRecordSchema
type Tex is Data:
  Tex{raw: String, display: Bool, recognized: Bool, evidenceId: String}

# documentBlockSchema (core subset; table modelled in a later step)
type Block is Data:
  Block{
    blockId: String,
    kind: BlockKind,
    tagName: String,
    sectionAnchor: String,
    authoredId: Maybe<&2, String>,
    headingLevel: Maybe<&2, U32>,
    ancestorSections: List<&2, String>,
    text: String,
    mapped: Bool,
    evidence: List<&2, Evidence>,
    links: List<&2, Link>,
    tex: List<&2, Tex>,
  }

# findingSchema (core subset; advisory arrays deferred)
type Finding is Data:
  Finding{
    recordId: String,
    rule: RuleRef,
    dimension: Dimension,
    origin: Origin,
    kind: FindingKind,
    title: String,
    message: String,
    evidence: List<&2, Evidence>,
    evidenceFingerprint: String,
    severity: Maybe<&2, Severity>,
  }

# comparisonRecordSchema (core subset)
type CompRecord is Data:
  CompRecord{
    outcome: Outcome,
    baseRecordId: Maybe<&2, String>,
    candidateRecordId: Maybe<&2, String>,
    reason: Maybe<&2, String>,
  }
