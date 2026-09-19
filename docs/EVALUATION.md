# Evaluation status

Prosemap now has two distinct evidence layers: executable implementation checks
and a frozen synthetic Markdown emission regression. Neither layer is an
independently annotated writing-defect study or evidence of comprehension gains.

## Frozen Markdown emission regression

`PROSEMAP_CMD=corpus bend prosemap/main.bend` reads
`fixtures/corpus/cases.tsv` plus its Markdown documents. Each row freezes the
document SHA-256, route, and complete expected set of emitted mechanical rule
IDs. The evaluator rejects malformed rows, unknown rule IDs, duplicate
document/route keys, unsafe filenames, missing documents, and hash mismatches.
Any missing or unexpected rule emission fails the run.

The current corpus has nine document/route cases. It positively exercises ten
of the twelve mechanical rules:

| Rule coverage | Cases |
| --- | --- |
| Heading depth and transition | deep heading jump |
| Duplicate authored ID | repeated `{#same}` |
| Expanded duplicate prose | whitespace-normalized repeated paragraph |
| Unresolved and resolved route edges | whole-document and `intro`-only routes |
| Case-similar notation | `$x$` and `$X$` in one section |
| ARI eligibility | paragraph above the configured word/sentence thresholds |
| Escaped pipes and ASCII diagram | prose source pattern plus fenced diagram |
| Clean control | no expected emissions |

The passing frozen result is 11 expected emissions, 0 unexpected emissions, and
0 missing emissions. Exact per-rule precision/recall is shown for regression
convenience, but it measures agreement with synthetic emission expectations,
not real-world defect accuracy.

`terminology.definition` and `terminology.introduction-density` remain
unassessed in this corpus: the Markdown extractor does not emit `dfn`, `strong`,
or `b` blocks. Their lower-level mechanical behavior remains smoke-tested, but
claiming positive Markdown corpus coverage would be false.

## Executable smoke and formal coverage

Standalone Bend programs under `prosemap/` exercise UTF-8 evidence integrity,
SHA-256 vectors, Markdown/math extraction, the mechanical rules, comparison,
replay gating, JSONL reconstruction, contextual evidence admission, subprocess
execution, and authored heading anchors. `bend PROOF.bend` checks seven stated
laws covering evidence construction/integrity, unassessed zero-denominator
metrics, conservative comparison and gate behavior, and finding-ID prefixes.

These checks establish deterministic implementation behavior only. They do not
prove extractor completeness, pedagogical usefulness, or provider judgment
quality.

## Contextual boundary

The provider-neutral subprocess stage accepts candidate records only when their
cited evidence IDs re-verify against the prepared source evidence. Reviews can
then reject accepted candidates before artifact emission. This path is
implemented and smoke-exercised; no live-provider accuracy, repeatability, cost,
or reviewer-agreement result is claimed.

## Remaining validation work

- obtain independently reviewed Markdown labels before reporting defect
  precision, recall, or rule usefulness;
- extend Markdown extraction if terminology rules should receive positive
  source-level corpus coverage;
- broaden Unicode and supported-Markdown boundary cases;
- evaluate contextual candidates against independent reviewers; and
- obtain direct reader-outcome evidence before making comprehension claims.
