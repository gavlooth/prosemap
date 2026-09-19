# Asset inventory

This inventory separates historical research material from assets consumed by the current Bend-only Markdown pipeline. Retaining an asset records its provenance; it does not make the asset an input or validation result for the implementation.

## Pipeline-consumed assets

| Asset | Current role |
| --- | --- |
| `fixtures/md/sample.md` | Operator-selectable Markdown smoke/input fixture. |
| `fixtures/corpus/cases.tsv` | Frozen SHA-256, route, and complete expected mechanical-rule emission sets for the `corpus` command. |
| `fixtures/corpus/*.md` | Eleven synthetic Markdown documents covering twelve document/route cases, including terminology extraction, malformed delimiter/code controls, and Unicode routing. |
| `fixtures/contextual-pilot/prompt.txt`, `responses.jsonl`, `findings.jsonl`, `reviews.jsonl`, `manifest.json` | Reproducible three-run contextual pilot and two-agent review data; explicitly non-human and non-generalizable. |

The corpus assets are deterministic regression inputs authored with the
implementation. They are not independent annotations and cannot establish
real-document defect precision, recall, or usefulness.

## Retained but unconsumed research assets

| Asset | Provenance/use record | Current Bend status |
| --- | --- | --- |
| `fixtures/calibration/problematic.html` | Synthetic calibration example with expected mechanical-rule labels in the fixture manifest. | Retained; not parsed or analyzed by the Bend pipeline. |
| `fixtures/regression/repaired.html` | Synthetic regression/control example. | Retained; not parsed or analyzed by the Bend pipeline. |
| `fixtures/heldout/route-dependent.html` | Synthetic held-out route-dependent example. | Retained; not parsed or analyzed by the Bend pipeline. |
| `fixtures/manifest.json` | Corpus split, expected labels, and frozen provenance record. | Retained; no Bend code reads it. |
| `fixtures/reader-profile.json` | Historical reader-profile configuration. | Retained; no Bend code reads it. |
| `fixtures/rules.json` | Historical rule configuration. | Retained; no Bend code reads it. |
| `fixtures/surface.json` | Historical surface-check configuration. | Retained; no Bend code reads it. |

The HTML examples and configurations remain useful research material for a future conversion/parity study. They must not be described as driving the present Markdown analysis, contextual transport, gate, evaluation, or any rendered-surface check.

## Frozen case-study provenance

The fixture manifest records a matching canonical HTML/export snapshot in the sibling `christos-cloudflare-page` repository:

- source revision: `f18a599279e8e74e6acba32701e5ec50b7377b55`;
- source location: `notes/pages/defects-to-topological-qubits.html`;
- source SHA-256: `74f42364f5c57e3e58bdf49cd4f8e15b9035901a13223f498e23300da3f99f0d`; and
- matching export manifest: `notes/qubits-exports.json`.

The same manifest records a separate partial sentence-audit provenance:

- summary: `.agents/qubits-sentence-audit-summary.json`;
- records: `.agents/qubits-sentence-audit.jsonl`;
- archived source: `.agents/qubits-sentence-audit-work.zip`, member `source.html`;
- source SHA-256: `704021172f8c15bd25222428bd0ef59bb0b3bf47130e224854cc0aac3f61d203`; and
- status: paused after 11,407 of 14,187 eligible records.

The manual `notes/topological-qubits-readability-report.md` has useful calibration hypotheses but is unlinked to an immutable source revision in the manifest. It is not ground truth for current output. The small fixture set likewise is not a claim to represent the complete manuscript.

## External tools and licensing record

The sibling repository's exporter and Chromium-oriented print utility remain external research references. The Bend program does not call, import, or depend on them. They may inform future requirements for a separately implemented conversion or surface-validation stage, but do not provide current pipeline behavior.

The prior licensing decision also remains: Coh-Metrix, TAACO, and TAALES implementations or lexicons are not vendored. Prosemap's exact lexical kernel is original Bend code with explicitly documented calculations; it does not claim feature parity with those tools. Any later use of their software, data, or lexicons needs a separate license review.
