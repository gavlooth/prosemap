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
- PASS/FAIL is reported on stdout. There is no exit-code policy; Bend's runner
  exits nonzero only on runtime errors such as an unreadable input file.

## Run

Bend has no argv, so the command and paths come from the environment.

```sh
# analyze: Markdown -> report.md + findings.jsonl + manifest.json (+ completion marker)
PROSEMAP_INPUT=fixtures/md/sample.md bend prosemap/main.bend

# gate: compare stored base vs candidate findings and enforce the CI policy
PROSEMAP_CMD=gate PROSEMAP_BASE=base.jsonl PROSEMAP_CANDIDATE=findings.jsonl \
  bend prosemap/main.bend
# -> "GATE PASS (0 violation(s))" or "GATE FAIL (n violation(s))"

# gate with replay verification: re-run deterministic analysis from source and
# require exact agreement with the stored findings before gating
PROSEMAP_CMD=gate PROSEMAP_BASE=base.jsonl PROSEMAP_CANDIDATE=findings.jsonl \
  PROSEMAP_BASE_SOURCE=base.md PROSEMAP_CANDIDATE_SOURCE=candidate.md \
  bend prosemap/main.bend

# evaluate: comparison + replay-verified gate over two runs
PROSEMAP_CMD=evaluate PROSEMAP_BASE_RUN=.runs/base PROSEMAP_CANDIDATE_RUN=.runs/candidate \
  bend prosemap/main.bend

# frozen synthetic rule-emission regression
PROSEMAP_CMD=corpus bend prosemap/main.bend
# -> per-rule exact counts followed by CORPUS PASS/FAIL
```

| Command | Environment | Output |
|---|---|---|
| `analyze` (default) | `PROSEMAP_INPUT`, `PROSEMAP_OUTPUT`, `PROSEMAP_JSONL`, `PROSEMAP_MANIFEST`, `PROSEMAP_COMPLETE`, optional `PROSEMAP_REVIEWS`, `PROSEMAP_READER`, `PROSEMAP_ROUTE`, `PROSEMAP_LLM_CMD` | report on stdout + three artifacts + completion marker |
| `gate` | `PROSEMAP_BASE`, `PROSEMAP_CANDIDATE`, optional `PROSEMAP_BASE_SOURCE`, `PROSEMAP_CANDIDATE_SOURCE` | `GATE PASS/FAIL (n violation(s))` |
| `evaluate` | `PROSEMAP_BASE`/`PROSEMAP_CANDIDATE` + both source variables, or `PROSEMAP_BASE_RUN`/`PROSEMAP_CANDIDATE_RUN` directories holding `input.md` + `findings.jsonl` | `EVALUATE PASS/FAIL (n comparison record(s))` |
| `context` | `PROSEMAP_INPUT`, `PROSEMAP_LLM_CMD` (unset ⇒ skipped), `PROSEMAP_LLM_TIMEOUT` (ms, def 60000), `PROSEMAP_LLM_MAX_BYTES` (def 1 MiB) | evidence-verified candidate lines |
| `latex` | `PROSEMAP_INPUT`, `PROSEMAP_KATEX_CMD` (unset ⇒ skipped) | `formula.unparsable` findings for unparsable math |
| `corpus` | optional `PROSEMAP_CORPUS_DIR` (default `fixtures/corpus`) | hash-verified per-rule emission matrix and `CORPUS PASS/FAIL` |

**FFI shim.** A single generic subprocess effect (`prosemap/effs/exec.js`, `Exec.run`) lets Bend
shell out to external tools; it powers `latex` (a real KaTeX/TeX parser), `context` (any LLM CLI —
prompt on stdin, JSON candidates on stdout, every cited evidence id re-verified against the source),
and is the pattern for pandoc-based ingestion. A failed tool probe abstains rather than flagging.

**Reviews.** `PROSEMAP_REVIEWS=reviews.jsonl` applies human dispositions during `analyze`; a line
`{"findingRecordId":..,"disposition":"rejected|accepted|needs-context","rationale":..}` with
`rejected` suppresses that finding from every artifact (and hence from the gate).

**Reader profile and reading route.** `PROSEMAP_READER=<file>` embeds the reader's declared
context (assumed knowledge, what is not assumed, objective) in the contextual prompt, so
candidates are judged for that reader rather than for no one. `PROSEMAP_ROUTE=<file>` scopes
analysis to a chosen set of section anchors, one per line: blocks whose section anchor is off the
route are not analyzed, so the run describes the reader's actual path through the document. An
unset or empty route is the whole document. Because off-route content is out of scope, a link
into an off-route section is reported as unresolved — the path being analyzed cannot follow it.
The reader profile and the route are independent: the route scopes the mechanical pass, the
profile conditions the contextual pass.

**Heading anchors.** A heading may carry an authored anchor: `## Methods {#methods}` makes
`methods` both the section anchor and the heading's authored ID, so `[text](#methods)` resolves
and a route can name `methods` instead of a byte offset. The marker is stripped from the heading
text; a heading without one keeps its `sec-<byte-offset>` anchor, and `{#}` names nothing.
Duplicate slugs are reported by `structure.duplicate-id`, like any other duplicated authored ID.

Because PASS/FAIL is a stdout contract, CI wraps it, for example:

```sh
PROSEMAP_CMD=gate ... bend prosemap/main.bend | grep -q '^GATE PASS'
```

## Artifacts

`analyze` writes `report.md`, `findings.jsonl` and `manifest.json`, then a completion
marker (`manifest.json.complete` by default) **last**. A bundle counts as committed
only when the marker exists, so an interrupted run cannot publish a complete run —
Bend's `File` API exposes no atomic rename, so visibility is marker-gated rather than
rename-atomic. The manifest's `sourceSha256` matches `sha256sum` of the input.

## Modules (`prosemap/`)

| File | Role |
|------|------|
| `types.bend` | core data model (enums + records), shared exact `Metric` |
| `contracts.bend` | evidence integrity (`Str.slice`, `Evidence.mk`, `integrity`) |
| `utf8.bend` | Unicode scalar → UTF-8 encoding, byte length, byte-boundary slicing |
| `sha256.bend` | pure SHA-256 over UTF-8 bytes (vector-verified) |
| `markdown.bend` | Markdown → `Block` list with UTF-8 byte offsets, `{#slug}`/offset section anchors, links, math/TeX |
| `mechanical.bend` | all 12 deterministic rules, including the command-aware TeX tokenizer |
| `cohesion.bend` | Jaccard / multiset-Dice as exact rationals |
| `route.bend` | reading-route scoping: keep only blocks whose section anchor is on the route |
| `reviews.bend` | human dispositions from `reviews.jsonl`; `rejected` suppresses a finding |
| `comparison.bend` | diff by `recordId` (`compare`) and rule/anchor grouping with conservative `unmatched` (`compare2`) |
| `gate.bend` | CI gate over newly added allowlisted observations, plus replay verification |
| `evaluation.bend` | comparison + replay-verified gate over two runs |
| `corpus.bend` | frozen Markdown corpus validation, exact emission scoring, and fail-closed input checks |
| `exec.bend` | the subprocess FFI shim (`effs/exec.js`) used by the `latex` and `context` stages |
| `latex.bend` | TeX snippets extracted from blocks → `formula.unparsable` findings via `PROSEMAP_KATEX_CMD` |
| `contextual.bend` | contextual requests, provider-neutral candidate parsing, and evidence re-verification |
| `json.bend` / `json_read.bend` | deterministic JSON emit / targeted findings reader |
| `report.bend` | findings → Markdown report |
| `artifacts.bend` | artifact commit protocol (write artifacts, then the marker) |
| `main.bend` | env-driven entry point: `analyze`, `gate`, `context`, `evaluate`, `latex`, `corpus` |

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
PROSEMAP_CMD=corpus bend prosemap/main.bend # frozen Markdown emission regression
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
