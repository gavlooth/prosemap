# Data contracts

This document describes the Bend records in `prosemap/types.bend` and the evidence rules in `prosemap/contracts.bend`. They are algebraic data types used by the deterministic pipeline. The persisted `findings.jsonl` form is intentionally a smaller, flat projection of a finding, not a serialization of every in-memory field.

## Common conventions

- **Source format:** Markdown. `prosemap/markdown.bend` constructs the blocks used by analysis.
- **Text addressing:** every `Span` is a half-open `[start, end)` range of **UTF-8 byte offsets**. It is not a line/column location and not a Unicode-code-point or UTF-16 offset.
- **Hashes:** `Sha256.hex` hashes the UTF-8 byte representation of a Bend string. Evidence document hashes and generated evidence fingerprints use this representation.
- **Optional values:** fields represented as `Maybe` are either present (`Some`) or absent (`None`); no fabricated default is implied.
- **Exact metrics:** a `Metric` is `Assessed{num, den}` or `Unassessed`. The numerator and denominator remain unreduced source counts.

## Blocks and extracted content

A `Block` has:

| Field | Meaning |
| --- | --- |
| `blockId` | Extractor-assigned block identifier. |
| `kind` | One of heading, prose, preformatted, math, table, figure, definition, or other. |
| `tagName` | The block's source-adapter tag label. The Markdown adapter uses labels such as `h1`, `p`, `pre`, and `math`. |
| `sectionAnchor` | Extractor-assigned section anchor. Markdown headings begin anchors such as `sec-<byte-offset>`; the initial section is `root`. |
| `authoredId`, `headingLevel`, `ancestorSections` | Optional/source-structure metadata retained by the core type. |
| `text`, `mapped` | Extracted text and whether the block is source mapped. |
| `evidence`, `links`, `tex` | The exact supporting evidence, internal-link records, and TeX records attached to the block. |

The Markdown adapter creates a flat block list. It recognizes ATX headings, blank-line-separated paragraphs, fenced code, fenced `math`, inline `$...$`, display `$$...$$`, and fragment links of the form `[text](#fragment)`. It does not claim to preserve arbitrary Markdown or other document formats as a full document model.

A `Link` records `href`, optional decoded fragment and target ID, and its evidence ID. A `Tex` record holds raw TeX, whether it is display math, whether it is recognized, and the evidence ID of its enclosing block.

## Evidence

An `Evidence` record contains:

- `id`, `documentSha256`, and `sourcePath`;
- `span: Span{start, end}`;
- `rawExcerpt` and separately retained `displayText`;
- `anchor: Anchor{section, block}`; and
- an evidence kind: prose, heading, link, TeX, table cell, caption, figure, definition, or source pattern.

`Evidence.mk` is the construction path used by the extractor. It derives `rawExcerpt` by slicing the supplied source at the byte span; callers do not provide the excerpt separately. `Evidence.integrity(source, evidence, expectedHash)` re-verifies both conditions: the evidence hash equals `expectedHash`, and the UTF-8 byte slice equals `rawExcerpt`. A directly constructed record can still be malformed; re-verification, rather than trust in a record shape, is the integrity boundary.

## Findings and identity

A `Finding` has:

| Field | Meaning |
| --- | --- |
| `recordId` | Stable mechanical identifier constructed as `<rule.id>:<first 20 fingerprint characters>`. |
| `rule` | `RuleRef{id, version}`. |
| `dimension` | Structure, formula, cohesion, terminology, notation, reference, source integrity, surface, or contextual. |
| `origin` and `kind` | Mechanical/model origin and observation/candidate kind. |
| `title`, `message` | Human-readable description. |
| `evidence` | Supporting evidence list. |
| `evidenceFingerprint` | Full SHA-256 of the canonical rule-and-evidence representation used by the mechanical constructor. |
| `severity` | Optional low, medium, or high severity. The present deterministic rules leave it absent. |

The canonical mechanical evidence representation includes each evidence kind, raw excerpt, and byte span, preceded by the rule ID and version. Thus a finding identity incorporates its rule namespace and evidence representation. It is not a line-number identity.

The compact JSONL emitter writes only `recordId`, rule as `id@version`, dimension, kind, title, message, and `evidenceFingerprint`. `prosemap/json_read.bend` reconstructs the fields needed for comparison and gating; it deliberately restores empty evidence and default mechanical origin rather than pretending to deserialize a complete finding record.

## Metrics

`Metric.mk(num, den)` produces `Unassessed` whenever `den` is zero; otherwise it produces `Assessed{num, den}`. No metric is assigned a numerical zero merely because no denominator exists. The display form is `num/den` or `unassessed`.

This representation is used by the cohesion kernel and terminology's `termsPerWords` measurement. Fixed-point outputs, such as ARI hundredths, are represented with integer arithmetic rather than floating point; see [Metrics](METRICS.md).

## Comparison and gate records

`CompRecord` contains an outcome and optional identifiers for the base and candidate sides, plus an optional reason:

- `Added`, `Resolved`, `Persisting`, `Changed`, or `Unmatched`;
- `baseRecordId` and `candidateRecordId`; and
- `reason`, used for example as `ambiguous group` by conservative grouping.

The direct comparison routine matches exact `recordId` values. The conservative `compare2` routine groups findings by rule ID/version and the sorted distinct evidence-section anchors. Unequal group cardinality is recorded entirely as `Unmatched`; it does not infer regressions from ambiguous groups.

`GateRes` is `passed: Bool` plus its `violations`. The built-in eligible rule set is `reference.unresolved@1` and `structure.duplicate-id@1`. A violation must additionally be newly added, mechanical, and an observation. `ReplayRes` adds `verified: Bool`; replay requires each stored JSONL string to exactly equal the canonical JSONL regenerated from its selected Markdown source.

## Enforced formal laws

`LAWS.bend` states seven laws discharged by `PROOF.bend`:

1. **`evidence_records_slice`** — `Evidence.mk` stores precisely the source slice for its span.
2. **`evidence_integrity_holds`** — evidence made by that constructor satisfies hash-and-slice re-verification for the supplied hash.
3. **`cohesion_empty_unassessed`** — comparing two empty token lists produces unassessed Jaccard and Dice metrics.
4. **`metric_zero_den_unassessed`** — every zero-denominator metric is unassessed.
5. **`empty_candidate_passes`** — an empty candidate finding set cannot fail the gate.
6. **`group_unequal_unmatched`** — unequal conservative comparison groups are all unmatched, never guessed as added or resolved.
7. **`finding_record_id_prefix`** — a mechanical record ID begins with its rule ID.

Run `bend PROOF.bend` to check these laws; successful discharge prints `All terms check.`.
