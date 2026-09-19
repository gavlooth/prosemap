# Evaluation status

Prosemap has four deliberately separate evidence layers:

1. executable implementation checks and seven machine-checked laws;
2. a frozen synthetic Markdown emission regression;
3. evaluators for externally adjudicated mechanical labels and independently
   reviewed contextual findings; and
4. a small, preserved non-human contextual pilot.

The first three are implemented and behaviorally verified. Layer 3 still needs
external adjudicated inputs before it can produce empirical accuracy results.
The repository contains no independent human defect corpus or reader-outcome
study, so it does not support claims of real-world defect accuracy or improved
comprehension.

## Frozen Markdown emission regression

`PROSEMAP_CMD=corpus bend prosemap/main.bend` reads
`fixtures/corpus/cases.tsv` plus its Markdown documents. Each row freezes the
document SHA-256, route, and complete expected set of emitted mechanical rule
IDs. The evaluator rejects malformed rows, unknown rule IDs, duplicate
document/route keys, unsafe filenames, missing documents, and hash mismatches.
Any missing or unexpected rule emission fails the run.

The current corpus has twelve document/route cases and positively exercises all
twelve mechanical rules:

| Rule coverage | Cases |
| --- | --- |
| Heading depth and transition | deep heading jump |
| Duplicate authored ID | repeated `{#same}` |
| Expanded duplicate prose | whitespace-normalized repeated paragraph |
| Unresolved and resolved route edges | whole-document, `intro`-only, and Unicode-anchor routes |
| Case-similar notation | `$x$` and `$X$` in one section |
| ARI eligibility | paragraph above configured word/sentence thresholds |
| Definition and introduction density | `<dfn>` plus two `**strong**` terms after a multibyte prefix |
| Escaped pipes and ASCII diagram | prose source pattern plus fenced diagram |
| Boundary controls | unclosed strong/definition/math delimiters and term syntax inside code |
| Clean control | no expected emissions |

The passing frozen result is 14 expected emissions, 0 unexpected emissions, and
0 missing emissions. Exact per-rule precision/recall is shown for regression
convenience, but it measures agreement with implementation-authored emission
expectations, not real-world defect accuracy.

## Adjudicated mechanical labels

`PROSEMAP_CMD=label-evaluate` reads a required `PROSEMAP_LABEL_DIR`. Its
`labels.tsv` rows contain document, SHA-256, route, defect-rule set, and
neutral-rule set; every unlisted rule is labeled absent. The evaluator verifies
hashes and schema, distinguishes neutral observations from defects, and reports
per-rule and total TP/FP/FN, neutral counts, exact precision, and exact recall.
Malformed, duplicate, unknown-rule, missing-file, and hash-mismatch inputs fail
closed.

This completes the reproducible evaluation workflow, not the empirical study.
Reviewer independence, label provenance, and adjudication are externally
asserted inputs. No bundled label set is called independent.

## Contextual review pilot

`PROSEMAP_CMD=review-evaluate` filters `contextual.model@1` findings and
requires at least two distinct reviewer IDs per finding. It reports consensus
accepted, rejected, needs-context, and disagreement counts, and fails on
malformed rows, orphan reviews, duplicate reviewer/finding pairs, or incomplete
review coverage.

`fixtures/contextual-pilot` preserves a three-run pilot on
`fixtures/md/sample.md`. Three `smol` model calls independently targeted the
same evidence (`ev-126`) and the same broad missing-context problem; two used
the same candidate kind. Two independently run clarity-reader agents agreed on
all three dispositions: two accepted and one rejected. The rejected candidate
overreached beyond its cited evidence by claiming that surrounding text and a
diagram lacked context. The saved evaluator result is coverage 3/3, consensus
accepted 2, consensus rejected 1, conflicts 0.

This pilot demonstrates admission, repeat generation, evidence-sensitive
review, and evaluator replay. It is one synthetic document, uses agent rather
than human reviewers, and records no monetary cost or reader outcome; it is not
a provider-quality estimate.

## Executable smoke and formal coverage

Standalone Bend programs exercise UTF-8 evidence integrity, SHA-256 vectors,
Markdown/math/term extraction, all mechanical rules, comparison, replay gating,
JSONL reconstruction, contextual admission, subprocess execution, adjudicated
label scoring, and independent-review scoring. `bend PROOF.bend` checks seven
stated laws covering evidence construction/integrity, unassessed
zero-denominator metrics, conservative comparison and gate behavior, and
finding-ID prefixes.

## External evidence still required

### Independent defect corpus

Independent reviewers must label real Markdown documents without seeing
Prosemap output, reconcile disagreements through a recorded adjudication
process, freeze document hashes, and supply the resulting `labels.tsv`. Keep a
held-out split that is never used for rule tuning. Until that input exists,
real-document precision, recall, and usefulness remain unmeasured.

### Human contextual study

Repeat the saved contextual protocol with a selected production provider,
representative documents, human reviewers, recorded latency/token/monetary
cost, and explicit abstention cases. The non-human pilot is implementation
evidence only.

### Reader outcomes

Before claiming improved comprehension, recruit the intended reader population
and preregister a blinded comparison of original versus revised passages.
Randomize passage order, use objective comprehension questions plus completion
time and confidence, record exclusions, and analyze both accuracy and time.
Participants, consent/ethics requirements, study material, and outcome data are
external prerequisites; no software-only substitute can complete this claim.
