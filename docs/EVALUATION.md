# Evaluation status

The current evidence is implementation-level: Bend smoke programs exercise defined behaviors, and a formal Bend proof discharges specified laws. It is not a corpus evaluation, a live-provider evaluation, or evidence that the tool improves comprehension.

## Executable smoke coverage

The smoke programs are standalone Bend programs under `prosemap/`. Run one as `bend prosemap/<name>_test.bend` (the basic program is `bend prosemap/test.bend`). They cover these concrete paths:

| Program(s) | Exercised behavior |
| --- | --- |
| `test`, `sha_test` | Evidence slicing/integrity, exact cohesion examples, and SHA-256 vectors. |
| `utf8_test` | UTF-8 byte length, byte slicing, Unicode SHA-256 input, and Markdown evidence spans. |
| `md_test`, `math_test` | Markdown blocks, heading/code analysis, inline/display/fenced math, and TeX extraction. |
| `mech_test`, `mech_test2`, `mech_test3` | Mechanical structure/reference/source-pattern rules, fixed-point ARI, terminology density, route-edge, expanded-duplicate, and case-similar notation paths. |
| `i3_test` | Introduction-density counting for `strong`, `b`, and `dfn` block tags. |
| `gate_test`, `jr_test` | Exact-record comparison, gate violations, compact JSONL reconstruction, and gating parsed findings. |
| `cmp2_test` | Conservative rule-and-anchor comparison: unequal groups become `unmatched`. |
| `ctx_test` | Evidence re-verification and rejection of a forged excerpt. |

These are smoke programs, not a labeled-corpus precision/recall suite. They demonstrate selected deterministic behaviors; they do not establish coverage for every Markdown construct or every document-writing failure mode.

## Formal evidence

`LAWS.bend` states seven properties, and `PROOF.bend` supplies their Bend proofs. `bend PROOF.bend` is the proof command and prints `All terms check.` when all terms check. The guarantees are narrow and explicit:

1. Evidence constructed with `Evidence.mk` records the source byte slice.
2. That constructed evidence satisfies hash-and-slice integrity re-verification.
3. Empty lexical comparison leaves Jaccard and Dice unassessed.
4. Any zero-denominator metric is unassessed.
5. An empty candidate finding set passes the gate.
6. Conservative comparison of unequal groups produces only unmatched records.
7. A mechanical finding ID begins with its rule ID.

The proof does not prove that Markdown extraction is complete, that a rule is pedagogically useful, that a source artifact represents the intended document, or that provider output is correct.

## Fixture status

`fixtures/md/sample.md` is the Markdown input fixture for the Bend pipeline. The pipeline does not automatically consume the fixture tree; an operator may pass this file as `PROSEMAP_INPUT`.

The retained calibration, regression, and held-out HTML files are not Bend inputs. Nor are `fixtures/manifest.json`, `reader-profile.json`, `rules.json`, or `surface.json` currently read by the Bend program. Their historical labels and expected-rule lists must therefore not be reported as Bend evaluation results.

In particular, the old HTML fixture split cannot currently provide parser parity, label precision/recall, or held-out performance evidence. Such a study first requires a separately specified HTML-to-Markdown bridge and a decision about what source-span equivalence means after conversion.

## Contextual boundary

The contextual module proves and smoke-exercises only the evidence re-verification predicate: cited excerpts must equal the source at their UTF-8 byte spans and carry the expected document hash. The command-side transport is a plaintext loopback POST to `127.0.0.1`; it prints a response body and does not parse, score, or persist a provider candidate.

No live-provider quality, repeatability, cost, safety, or human-agreement result is claimed. The evidence predicate is necessary for accepting cited candidates, but it does not establish the truth or usefulness of their prose judgments.

## Open validation work

The following remain open rather than implied by the smoke programs or laws:

- corpus-level rule evaluation on Markdown fixtures with independently reviewed labels;
- a documented conversion/parity study before reusing retained HTML assets as Bend evaluation data;
- broader Unicode and Markdown-construct coverage beyond the extractor's supported subset;
- an end-to-end contextual-provider protocol that parses candidate records and applies the verified-evidence admission predicate;
- reader studies or other independent evidence for comprehension effects; and
- any rendered-surface validation. Chromium checks, HTML ingestion, PDF checks, and HTTPS transport are not implemented by this Bend pipeline.
