# Architecture

## Scope

Prosemap is a local Bend program for deterministic analysis of **Markdown**. Its source lives at the repository root: `prosemap/*.bend`, with the formal laws in `LAWS.bend` and their proofs in `PROOF.bend`. It is not a service and it has no browser, HTML parser, remote transport, or package-runtime layer.

Other document formats are outside the input adapter. Convert them to Markdown before analysis—for example, with Pandoc—and retain that conversion as an external workflow rather than treating it as part of Prosemap.

## Runtime boundary

`bin/prosemap` is the public CLI. It accepts positional commands and ordinary
flags, resolves the repository and Bend executable, chooses artifact paths,
rejects invalid arguments, and maps printed policy PASS/FAIL to conventional
process exit status. Because Bend has no argv interface, the wrapper translates
those arguments into this private `main.bend` protocol:

| Internal command | Inputs | Result |
| --- | --- | --- |
| `analyze` (default) | `PROSEMAP_INPUT` plus optional route, reader, reviews, and LLM command | Deterministic analysis, admitted contextual candidates, artifacts, and report. |
| `gate` | `PROSEMAP_BASE` and `PROSEMAP_CANDIDATE` findings JSONL files | Gate result; optional source paths enable replay verification. |
| `evaluate` | Explicit findings/source paths, or paired run directories | Replay-verified gate result and comparison-record count. |
| `context` | `PROSEMAP_INPUT`, `PROSEMAP_LLM_CMD` | Evidence-verified contextual candidate lines; unset command skips. |
| `latex` | `PROSEMAP_INPUT`, `PROSEMAP_KATEX_CMD` | Findings for snippets rejected by the configured TeX parser. |
| `corpus` | optional `PROSEMAP_CORPUS_DIR` | Frozen synthetic emission regression. |
| `label-evaluate` | required `PROSEMAP_LABEL_DIR` | Adjudicated defect/neutral/absent rule scoring. |
| `review-evaluate` | findings and review JSONL paths | Contextual-review coverage and agreement report. |

The Bend entry point prints policy results to stdout. The public wrapper returns
0 for PASS, 1 for a printed FAIL, 2 for CLI misuse, and the underlying Bend
status for runtime errors.

## Module boundaries

| Module(s) | Responsibility | Boundary and limits |
| --- | --- | --- |
| `install.sh` | User-local installation | Creates and verifies a symlink in `~/.local/bin` or `--bin-dir`; refuses unrelated existing targets unless `--force` is explicit. |
| `bin/prosemap` | Public command-line interface | Parses positional commands and flags, isolates invocations from inherited `PROSEMAP_*` variables, and translates Bend policy output into exit status. |
| `prosemap/types.bend` | Core algebraic data types for blocks, evidence, findings, metrics, and comparisons | Defines the in-memory records; it does not validate general JSON. |
| `prosemap/utf8.bend`, `prosemap/sha256.bend`, `prosemap/contracts.bend` | UTF-8 byte operations, pure SHA-256, evidence construction and re-verification | Evidence spans are UTF-8 byte offsets and excerpts are re-sliced from source. |
| `prosemap/markdown.bend` | Markdown extraction | Extracts ATX headings, paragraphs, fenced code/math, inline/display TeX, internal links, `**strong**` terms, and `<dfn>` definitions into source-mapped blocks. |
| `prosemap/mechanical.bend`, `prosemap/cohesion.bend` | Deterministic mechanical rules and lexical metric kernel | Findings are constructed from source evidence. Cohesion is an exact-token metric kernel, not a comprehension judgment. |
| `prosemap/report.bend`, `prosemap/json.bend`, `prosemap/json_read.bend` | Markdown reporting and the compact findings JSONL interchange form | The reader recognizes the emitter's flat findings format; it is not a general JSON parser. |
| `prosemap/comparison.bend`, `prosemap/gate.bend`, `prosemap/evaluation.bend`, `prosemap/corpus.bend` | Finding comparison, replay verification, gating, and frozen regression | Synthetic emission agreement is kept distinct from adjudicated defect accuracy. |
| `prosemap/label_eval.bend`, `prosemap/review_eval.bend` | Adjudicated rule scoring and contextual-review evaluation | Validate hashes, labels, reviewer coverage, orphans, duplicates, and disagreement; reviewer independence remains external provenance. |
| `prosemap/artifacts.bend` | Artifact write ordering | Writes the completion marker last; Bend's file API supplies no atomic rename. |
| `prosemap/contextual.bend`, `prosemap/exec.bend` | Provider-neutral prompt/candidate boundary and bounded subprocess execution | Only candidates citing prepared evidence IDs are admitted; provider failure abstains. |
| `prosemap/main.bend` | Private environment dispatch and file I/O | Receives only the wrapper's normalized internal protocol and coordinates the Bend modules. |

## Analyze flow

`analyze` performs one pure analysis pass before persistence:

1. Read the Markdown input and compute its SHA-256 over UTF-8 bytes.
2. Parse Markdown into blocks with byte-addressed evidence.
3. Run the deterministic mechanical analyzer with heading-depth threshold `4` and its default ARI and terminology thresholds.
4. Render the same finding list as `report.md`, `findings.jsonl`, and `manifest.json` content.
5. Write those three artifacts, then write the completion marker, and print the report.

The configurable paths are `PROSEMAP_OUTPUT` (default `report.md`), `PROSEMAP_JSONL` (default `findings.jsonl`), `PROSEMAP_MANIFEST` (default `manifest.json`), and `PROSEMAP_COMPLETE` (default `manifest.json.complete`). A consumer that uses the marker convention treats the bundle as complete only after the marker exists. Because the file API has no atomic rename and paths are writable outputs, callers needing isolation must choose a fresh output location.

The manifest is a compact deterministic record: schema version, tool version, format `markdown`, source SHA-256, finding count, and the enabled-rule list. The JSONL emitter writes one compact finding object per line. The Markdown report contains a count and one entry per finding.

## Replay, comparison, and gate

The normal comparison path identifies exact `recordId` matches, producing added, resolved, and persisting records. `compare2` also exists for rule-and-anchor groups: when group cardinalities differ or leftovers are ambiguous, it emits `unmatched` rather than guessing added or resolved; a one-to-one leftover pair becomes `changed`.

The gate compares stored base and candidate findings. Its eligible rules are `reference.unresolved@1` and `structure.duplicate-id@1`; a violation must be a newly added, allowlisted, mechanical **observation**. Candidates and findings outside that predicate remain advisory.

Supplying both `PROSEMAP_BASE_SOURCE` and `PROSEMAP_CANDIDATE_SOURCE` selects replay mode. It re-runs Markdown parsing and mechanical analysis for both sources, regenerates canonical JSONL, and requires exact string equality with each stored JSONL artifact. Missing one of the two replay sources or any disagreement fails closed. `evaluate` always uses this replay verification: it accepts either explicit base/candidate findings plus both sources, or `PROSEMAP_BASE_RUN` and `PROSEMAP_CANDIDATE_RUN` directories containing `input.md` and `findings.jsonl`.

## Contextual and review boundary

`analyze` and `context` prepare source-verified evidence IDs and pass the prompt
to `PROSEMAP_LLM_CMD` through the bounded subprocess effect. Candidate JSONL is
accepted only when its `evidenceId` is in that prepared set. `analyze` converts
accepted lines into advisory `contextual.model@1` findings, applies rejected
review IDs, and writes the merged findings into ordinary artifacts.

`review-evaluate` then checks whether every contextual finding has at least two
distinct reviewer IDs. It reports consensus accepted/rejected/needs-context
counts and disagreements, and fails on malformed, orphan, duplicate, or
under-reviewed data. It cannot prove that IDs identify independent humans.

`label-evaluate` consumes hash-frozen Markdown plus complete rule-family labels:
defect, neutral, or absent. It reports exact TP/FP/FN and neutral-observation
counts. Annotation and adjudication provenance remain external study inputs.

## Verification status

The repository contains executable Bend smoke programs for hashing, UTF-8 byte spans, Markdown extraction, mechanical rules, TeX/notation, exact metrics, JSONL reconstruction, gate behavior, conservative comparison, and contextual evidence verification. The formal boundary is stronger for seven specified properties: `bend PROOF.bend` discharges every law in `LAWS.bend` and prints `All terms check.` on success. See [Evaluation](EVALUATION.md) for the precise scope and remaining validation work.
