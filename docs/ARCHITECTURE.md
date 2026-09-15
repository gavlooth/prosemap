# Architecture

## Scope

Prosemap is a local Bend program for deterministic analysis of **Markdown**. Its source lives at the repository root: `prosemap/*.bend`, with the formal laws in `LAWS.bend` and their proofs in `PROOF.bend`. It is not a service and it has no browser, HTML parser, remote transport, or package-runtime layer.

Other document formats are outside the input adapter. Convert them to Markdown before analysis—for example, with Pandoc—and retain that conversion as an external workflow rather than treating it as part of Prosemap.

## Runtime boundary

Bend has no argv interface, so `prosemap/main.bend` is configured entirely through environment variables:

| `PROSEMAP_CMD` | Inputs | Result |
| --- | --- | --- |
| `analyze` (default) | `PROSEMAP_INPUT` (default `input.md`) | Deterministic analysis, artifacts, and a printed Markdown report. |
| `gate` | `PROSEMAP_BASE` and `PROSEMAP_CANDIDATE` findings JSONL files | A gate result; optional source paths enable replay verification. |
| `evaluate` | Explicit findings/source paths, or paired run directories | A replay-verified gate result and comparison-record count. |
| `context` | `PROSEMAP_INPUT`, `PROSEMAP_PROVIDER_PORT` (default `8899`) | The body returned by a loopback contextual provider. |

The commands print their result to stdout. `gate` prints `GATE PASS (n violation(s))` or `GATE FAIL (...)`; `evaluate` prints `EVALUATE PASS` or `EVALUATE FAIL` with its comparison-record count. There is **no Prosemap exit-code policy**: Bend reports nonzero only for runtime failures such as an unreadable input file, not for a printed PASS or FAIL.

## Module boundaries

| Module(s) | Responsibility | Boundary and limits |
| --- | --- | --- |
| `prosemap/types.bend` | Core algebraic data types for blocks, evidence, findings, metrics, and comparisons | Defines the in-memory records; it does not validate general JSON. |
| `prosemap/utf8.bend`, `prosemap/sha256.bend`, `prosemap/contracts.bend` | UTF-8 byte operations, pure SHA-256, evidence construction and re-verification | Evidence spans are UTF-8 byte offsets and excerpts are re-sliced from source. |
| `prosemap/markdown.bend` | Markdown extraction | Extracts ATX headings, paragraphs, fenced code, fenced `math`, inline/display TeX, and internal fragment links into flat blocks. It is not an HTML adapter. |
| `prosemap/mechanical.bend`, `prosemap/cohesion.bend` | Deterministic mechanical rules and lexical metric kernel | Findings are constructed from source evidence. Cohesion is an exact-token metric kernel, not a comprehension judgment. |
| `prosemap/report.bend`, `prosemap/json.bend`, `prosemap/json_read.bend` | Markdown reporting and the compact findings JSONL interchange form | The reader recognizes the emitter's flat findings format; it is not a general JSON parser. |
| `prosemap/comparison.bend`, `prosemap/gate.bend`, `prosemap/evaluation.bend` | Finding comparison, allowlisted gate, replay verification, evaluation flow | The gate only fails for newly added eligible mechanical observations. |
| `prosemap/artifacts.bend` | Artifact write ordering | Writes the completion marker last; Bend's file API supplies no atomic rename. |
| `prosemap/contextual.bend` | Evidence re-verification and loopback request helper | The transport is plaintext loopback TCP/HTTP only; it has no DNS, TLS, or HTTPS. |
| `prosemap/main.bend` | Environment dispatch and file I/O | Coordinates the commands above without adding a second execution model. |

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

## Contextual boundary

The `context` command connects only to `127.0.0.1` on `PROSEMAP_PROVIDER_PORT` (default `8899`) and issues a plaintext HTTP POST to `/contextual`. It prints the response body. There is no DNS lookup, TLS, HTTPS, provider SDK, credential handling, response-schema decoding, or artifact persistence in this command.

Separately, `Ctx.all_verified` is the admission predicate for evidence-backed candidates: every cited evidence item must reproduce the recorded source slice and document hash. The pure `Ctx.verify` helper drops evidence that fails that test. A raw provider response is therefore not, by itself, an accepted contextual finding.

## Verification status

The repository contains executable Bend smoke programs for hashing, UTF-8 byte spans, Markdown extraction, mechanical rules, TeX/notation, exact metrics, JSONL reconstruction, gate behavior, conservative comparison, and contextual evidence verification. The formal boundary is stronger for seven specified properties: `bend PROOF.bend` discharges every law in `LAWS.bend` and prints `All terms check.` on success. See [Evaluation](EVALUATION.md) for the precise scope and remaining validation work.
