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
cross-version comparison, a replay-verified CI gate, and an opt-in contextual stage
whose evidence references are re-verified before any candidate is accepted.

Honest boundaries:

- **Input is Markdown.** Pandoc is the bridge for HTML and other formats.
- **No Chromium/surface stage.** Rendering checks are not implemented here.
- **Contextual transport is loopback TCP only.** Bend has no DNS/TLS, so remote
  HTTPS providers need an external bridge.
- **PASS/FAIL is reported on stdout.** There is no exit-code policy; Bend's runner
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
```

| Command | Environment | Output |
|---|---|---|
| `analyze` (default) | `PROSEMAP_INPUT`, `PROSEMAP_OUTPUT`, `PROSEMAP_JSONL`, `PROSEMAP_MANIFEST`, `PROSEMAP_COMPLETE` | report on stdout + three artifacts + completion marker |
| `gate` | `PROSEMAP_BASE`, `PROSEMAP_CANDIDATE`, optional `PROSEMAP_BASE_SOURCE`, `PROSEMAP_CANDIDATE_SOURCE` | `GATE PASS/FAIL (n violation(s))` |
| `evaluate` | `PROSEMAP_BASE`/`PROSEMAP_CANDIDATE` + both source variables, or `PROSEMAP_BASE_RUN`/`PROSEMAP_CANDIDATE_RUN` directories holding `input.md` + `findings.jsonl` | `EVALUATE PASS/FAIL (n comparison record(s))` |
| `context` | `PROSEMAP_INPUT`, `PROSEMAP_PROVIDER_PORT` (default 8899) | contextual response body |

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
| `markdown.bend` | Markdown → `Block` list with UTF-8 byte offsets, section anchors, links, math/TeX |
| `mechanical.bend` | all 12 deterministic rules, including the command-aware TeX tokenizer |
| `cohesion.bend` | Jaccard / multiset-Dice as exact rationals |
| `comparison.bend` | diff by `recordId` (`compare`) and rule/anchor grouping with conservative `unmatched` (`compare2`) |
| `gate.bend` | CI gate over newly added allowlisted observations, plus replay verification |
| `evaluation.bend` | comparison + replay-verified gate over two runs |
| `contextual.bend` | contextual requests, loopback TCP transport, evidence re-verification |
| `json.bend` / `json_read.bend` | deterministic JSON emit / targeted findings reader |
| `report.bend` | findings → Markdown report |
| `artifacts.bend` | artifact commit protocol (write artifacts, then the marker) |
| `main.bend` | env-driven entry point: `analyze`, `gate`, `context`, `evaluate` |

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
bend prosemap/md_test.bend            # Markdown → findings
bend prosemap/math_test.bend          # Markdown math + TeX command tokenizer
bend prosemap/gate_test.bend          # gate behavior
bend prosemap/cmp2_test.bend          # comparison grouping
bend prosemap/ctx_test.bend           # contextual evidence re-verification
bend prosemap/i3_test.bend            # rule-ID / finding construction
bend prosemap/jr_test.bend            # findings.jsonl reader
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
