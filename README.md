# Prosemap

Evidence-backed readability and pedagogical structure analysis for long technical documents.

Implemented in [Bend 2](https://github.com/bendlang/bend) — a statically typed,
proof-carrying functional language. The whole analysis core is Bend source: Markdown
parsing, 12 deterministic mechanical rules, exact cohesion metrics, conservative
comparison, a replay-verified CI gate, evidence re-verification, JSON/Markdown
artifacts, and machine-checked laws for the invariants the pipeline depends on.

The objective is an evidence-producing reviewer: mechanical observations plus optional
semantic judgment. Neither formula scores nor embedding similarity establish
comprehension.

## Status

Working local CLI with source-backed mechanical analysis, immutable run artifacts,
cross-version comparison, a replay-verified CI gate, a frozen Markdown emission
regression corpus, real TeX parser integration, and an opt-in provider-neutral
contextual stage whose evidence references are re-verified before acceptance.

Operational boundaries:

- Input and source evidence are Markdown.
- Contextual and TeX tools run through a bounded subprocess FFI; failures abstain.
- The public `bin/prosemap` command returns conventional success/failure status;
  the underlying Bend entry point communicates policy PASS/FAIL on stdout.

## Install the command

The Bend core has no argument API, so `bin/prosemap` provides the normal
human-facing command line and keeps the internal environment protocol hidden.
Run it directly:

```sh
./bin/prosemap --help
```

Or put it on your path:

```sh
mkdir -p ~/.local/bin
ln -sf "$(pwd)/bin/prosemap" ~/.local/bin/prosemap
```

The wrapper finds `bend` on `PATH`, then falls back to
`~/.bend/bin/bend`.

## Analyze a document

```sh
prosemap document.md
```

That prints the report and writes a complete run to
`.prosemap/document/`:

- `report.md` — human-readable findings;
- `findings.jsonl` — machine-readable findings;
- `manifest.json` — source hash and run metadata; and
- `manifest.json.complete` — written last, proving the bundle completed.

Choose another output directory or explicitly spell the command:

```sh
prosemap document.md --out .runs/document
prosemap analyze document.md --out .runs/document
```

Optional analysis flags:

```text
--route FILE       section anchors to analyze, one per line
--reader FILE      intended-reader profile for contextual review
--reviews FILE     accepted/rejected/needs-context review JSONL
--llm-cmd COMMAND  optional contextual-model command
```

## Other commands

```sh
# verify the built-in regression corpus
prosemap corpus

# replay-verified CI comparison; exits 1 on a reported gate failure
prosemap gate base.jsonl candidate.jsonl base.md candidate.md

# compare two stored run directories
prosemap evaluate .runs/base .runs/candidate

# run only the contextual stage
prosemap context document.md --llm-cmd "your-llm-cli"

# validate formulas with an external KaTeX-compatible command
prosemap latex document.md --katex-cmd "your-katex-cli"

# score externally adjudicated mechanical labels
prosemap label-evaluate /path/to/adjudicated-corpus

# check contextual findings reviewed by two or more reviewers
prosemap review-evaluate findings.jsonl reviews.jsonl
```

`corpus`, `gate`, `evaluate`, `label-evaluate`, and `review-evaluate` return
nonzero when their printed result is FAIL. Run `prosemap help` for the complete
syntax.

## Optional contextual review

The command passed to `--llm-cmd` receives a prompt on stdin and emits one JSON
candidate per line on stdout. Every cited evidence ID is checked against the
source before the candidate is admitted. A failed or timed-out command abstains
instead of inventing a finding.

`--reviews reviews.jsonl` applies dispositions during analysis. A review line
has this form:

```json
{"findingRecordId":"contextual:abc","reviewer":"alice","disposition":"rejected","rationale":"The cited paragraph already defines the term."}
```

Rejected findings are omitted from the report and artifacts.

For adjudicated mechanical evaluation, `labels.tsv` has five tab-separated
fields: `document`, `sha256`, `route`, `defect-rules`, and `neutral-rules`.
Use `-` for an empty route or rule set; every unlisted rule is labeled absent.

`review-evaluate` requires two distinct reviewer IDs for every
`contextual.model@1` finding. It fails on missing coverage, malformed rows,
orphan reviews, or duplicate reviewer/finding pairs; disagreement is reported
rather than silently resolved.

**Reader profile and reading route.** `--reader <file>` embeds the reader's
declared context (assumed knowledge, what is not assumed, objective) in the
contextual prompt. `--route <file>` scopes analysis to the listed section
anchors. An unset or empty route means the whole document. Because off-route
content is out of scope, a link into an excluded section is reported as
unresolved. The route scopes the mechanical pass; the profile conditions the
contextual pass.

**Heading anchors.** A heading may carry an authored anchor: `## Methods {#methods}` makes
`methods` both the section anchor and the heading's authored ID, so `[text](#methods)` resolves
and a route can name `methods` instead of a byte offset. The marker is stripped from the heading
text; a heading without one keeps its `sec-<byte-offset>` anchor, and `{#}` names nothing.
Duplicate slugs are reported by `structure.duplicate-id`, like any other duplicated authored ID.

The `bin/prosemap` wrapper converts printed PASS/FAIL results into conventional
process exit status: PASS returns 0 and FAIL returns 1. Directly invoking the
Bend entry point remains an internal interface whose PASS/FAIL contract is
stdout-only.

## Artifacts

`analyze` writes `report.md`, `findings.jsonl` and `manifest.json`, then a completion
marker (`manifest.json.complete` by default) **last**. A bundle counts as committed
only when the marker exists, so an interrupted run cannot publish a complete run —
Bend's `File` API exposes no atomic rename, so visibility is marker-gated rather than
rename-atomic. The manifest's `sourceSha256` matches `sha256sum` of the input.

## Modules (`prosemap/`)

`bin/prosemap` is the public argument-based CLI. It validates arguments,
selects output paths, translates policy results to exit status, and invokes the
Bend core.

| File | Role |
|------|------|
| `types.bend` | core data model (enums + records), shared exact `Metric` |
| `contracts.bend` | evidence integrity (`Str.slice`, `Evidence.mk`, `integrity`) |
| `utf8.bend` | Unicode scalar → UTF-8 encoding, byte length, byte-boundary slicing |
| `sha256.bend` | pure SHA-256 over UTF-8 bytes (vector-verified) |
| `markdown.bend` | Markdown → `Block` list with UTF-8 byte offsets, `{#slug}`/offset section anchors, links, math/TeX, `**strong**`, and `<dfn>` terms |
| `mechanical.bend` | all 12 deterministic rules, including the command-aware TeX tokenizer |
| `cohesion.bend` | Jaccard / multiset-Dice as exact rationals |
| `route.bend` | reading-route scoping: keep only blocks whose section anchor is on the route |
| `reviews.bend` | human dispositions from `reviews.jsonl`; `rejected` suppresses a finding |
| `comparison.bend` | diff by `recordId` (`compare`) and rule/anchor grouping with conservative `unmatched` (`compare2`) |
| `gate.bend` | CI gate over newly added allowlisted observations, plus replay verification |
| `evaluation.bend` | comparison + replay-verified gate over two runs |
| `corpus.bend` | frozen Markdown corpus validation, exact emission scoring, and fail-closed input checks |
| `label_eval.bend` | adjudicated defect/neutral/absent labels → exact rule-level TP/FP/FN |
| `review_eval.bend` | independent contextual-review coverage, consensus, disagreement, and integrity checks |
| `exec.bend` | the subprocess FFI shim (`effs/exec.js`) used by the `latex` and `context` stages |
| `latex.bend` | TeX snippets extracted from blocks → `formula.unparsable` findings for the command supplied with `--katex-cmd` |
| `contextual.bend` | contextual requests, provider-neutral candidate parsing, and evidence re-verification |
| `json.bend` / `json_read.bend` | deterministic JSON emit / targeted findings reader |
| `report.bend` | findings → Markdown report |
| `artifacts.bend` | artifact commit protocol (write artifacts, then the marker) |
| `main.bend` | internal environment-driven Bend entry point used by `bin/prosemap` |

## Laws

`bend PROOF.bend` prints `All terms check.` when every law holds; it is the proof gate.

Seven laws: `evidence_records_slice`, `evidence_integrity_holds` (full evidence
re-verification), `cohesion_empty_unassessed` (no tokens ⇒ `Unassessed`),
`metric_zero_den_unassessed` (any zero-denominator metric ⇒ `Unassessed`),
`empty_candidate_passes` (gate conservatism), `group_unequal_unmatched` (comparison
conservatism), `finding_record_id_prefix` (every sanctioned finding ID starts with its
rule ID).

## Deliberate representations

- **UTF-8 byte offsets** for evidence spans (Bend strings are codepoint lists).
- **Exact rationals / fixed point** for cohesion metrics and ARI — Base has no float
  display and floats can diverge across platforms, while the gate demands bit-exact
  agreement.
- **Deterministic JSON** for findings and manifests.

## Tests

Smoke programs are Bend source; run each directly.

```sh
bend PROOF.bend                       # all laws
bend prosemap/test.bend               # slice/evidence integrity + cohesion
bend prosemap/sha_test.bend           # SHA-256 vectors
bend prosemap/utf8_test.bend          # multibyte lengths, slicing, hashing
bend prosemap/mech_test.bend          # mechanical rules
bend prosemap/mech_test2.bend         # per-section metrics
bend prosemap/mech_test3.bend         # newer rules
bend prosemap/md_test.bend            # Markdown → blocks, findings, {#slug} anchors
bend prosemap/math_test.bend          # Markdown math + TeX command tokenizer
bend prosemap/gate_test.bend          # gate behavior
bend prosemap/cmp2_test.bend          # comparison grouping
bend prosemap/ctx_test.bend           # contextual evidence re-verification
bend prosemap/i3_test.bend            # rule-ID / finding construction
bend prosemap/jr_test.bend            # findings.jsonl reader
bend prosemap/study_test.bend         # adjudicated labels + independent reviews
bin/prosemap corpus                    # frozen Markdown emission regression
bin/prosemap review-evaluate \
  fixtures/contextual-pilot/findings.jsonl \
  fixtures/contextual-pilot/reviews.jsonl # preserved non-human pilot replay
```

## Design

- [Plan](docs/PLAN.md): motivation, research background, roadmap and evaluation.
- [Architecture](docs/ARCHITECTURE.md): Bend module boundaries and execution flow.
- [Contracts](docs/CONTRACTS.md): data records and invariants.
- [Assets](docs/ASSET_INVENTORY.md): frozen case-study provenance and reuse decisions.
- [Metrics](docs/METRICS.md): exact mechanical calculations and limits.
- [Evaluation](docs/EVALUATION.md): fixture results and unresolved validation requirements.

The HTML fixtures under `fixtures/` (`calibration/problematic.html`,
`heldout/route-dependent.html`, `regression/repaired.html`) and their configuration
files are retained research assets; the Bend pipeline does not consume them — it
analyzes Markdown (`fixtures/md/sample.md`).

The reference manuscript lives in the sibling christos-cloudflare-page repository. It
is neither copied nor a runtime dependency. No Python code or dependency is included.
The contextual bridge is provider-neutral and opt-in; no remote provider or publication
target is selected.
