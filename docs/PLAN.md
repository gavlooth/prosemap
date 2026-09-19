# Prosemap roadmap and research notes

## Current implementation decision

Prosemap is implemented as a Bend-only, Markdown-first pipeline at the repository root. The implemented core is deterministic block extraction, UTF-8 byte-addressed evidence, SHA-256 identity, mechanical analysis, report/JSONL/manifest artifacts, comparison, replay verification, an allowlisted gate, and a loopback-only contextual transport helper.

The implementation does **not** ingest HTML, execute a rendered-surface stage, use Chromium, provide HTTPS transport, or claim a provider integration. Those are deferred research and engineering work, not hidden capabilities. See [Architecture](ARCHITECTURE.md), [Contracts](CONTRACTS.md), and [Evaluation](EVALUATION.md).

## 1. Motivation

The original readability audit of a technical reader was performed manually: reviewers identified term clustering, fractured headings, broken tables, notation collisions, and missing explanatory bridges. That work motivates repeatable evidence-producing analysis, but it does not license an automated claim that a text is understood or misunderstood.

The useful question is narrower: which source-grounded observations can be regenerated after an edit, compared conservatively, and presented for review? Prosemap records deterministic mechanical observations and candidates. It does not produce a single validated readability score.

## 2. Research frame

### Readability formulas

Flesch, Flesch–Kincaid, Gunning Fog, Dale–Chall, SMOG, and Coleman–Liau demonstrate that cheap surface measures can be useful flags. They measure word-, sentence-, and sometimes familiar-word properties; they do not identify a conceptually missing bridge or establish why a passage is difficult. The implemented ARI is consequently reported as an observation, never an automatic defect target.

### Cognitive load and pedagogical structure

Cognitive-load work distinguishes material-related difficulty from presentation-related avoidable burden. Headings, definitions, notation, and explicit links can provide evidence about organization, but they do not reveal a reader's prior knowledge or prove learning. An apparent term cluster may be appropriate for advanced material; an easy-looking paragraph may still conceal a missing prerequisite.

### Cohesion and comprehension

Text-cohesion research motivates measuring lexical relationships, but a shared vocabulary is not referent resolution or comprehension. `prosemap/cohesion.bend` therefore exposes exact Jaccard and multiset-Dice token metrics without turning them into a quality score. Its current ASCII-fold tokenization and English stop words are explicit limits, not a claim of language-general analysis.

### Related tools and licensing

Coh-Metrix, TAACO, and TAALES are relevant precedents for cohesion and lexical analysis. Their implementations and lexicons are not imported. The retained asset record notes this licensing boundary; any future adoption requires separate review and must not be represented as feature parity.

## 3. Design principle: observations are not judgments

The implementation distinguishes what it can mechanically establish from what still needs interpretation:

- **Mechanical findings** have a rule ID/version, a deterministic evidence fingerprint, source-derived evidence, and observation or candidate kind. They can flag conditions such as heading depth, unresolved internal fragments, source patterns, ARI eligibility/value, or explicitly marked term density.
- **Contextual work** is not currently an integrated judgement engine. The loopback helper can obtain a response body, while the evidence module can reject citations whose byte spans or document hash do not re-verify. It neither parses a provider response into findings nor establishes that a cited claim is useful or true.
- **Human evaluation** remains necessary for pedagogy, reader-route assumptions, semantic ambiguity, and any proposed repair.

Every evidence-backed claim should preserve the exact source excerpt and UTF-8 byte span. Source evidence is stronger than a summary or a guessed line location, but it is not proof of a diagnosis.

## 4. Implemented pipeline

```text
Markdown input
    |
    +--> UTF-8 SHA-256
    +--> Markdown blocks + byte-addressed evidence
    +--> deterministic mechanical findings
    |       +--> Markdown report
    |       +--> compact findings JSONL
    |       +--> compact manifest
    |              +--> completion marker written last
    |
    +--> stored base/candidate JSONL
            +--> direct or conservative comparison
            +--> optional source replay
            +--> narrow mechanical gate
```

The Markdown extractor supports ATX headings, paragraphs, fenced code, fenced `math`, inline/display TeX, and internal fragment links. It is deliberately not an all-format document-normalization layer. Other inputs must be converted outside the program, for example with Pandoc.

The default analysis runs twelve deterministic mechanical rule families. The gate intentionally applies a much smaller policy: only new, mechanical observations for `reference.unresolved@1` or `structure.duplicate-id@1` can violate it, and those rules must also be allowed by the passed allowlist. All other emitted findings are advisory.

Artifact persistence writes report, findings JSONL, and manifest before a `complete` marker. The marker convention provides completion ordering but not atomic replacement, because Bend's file API does not expose atomic rename. Consumers that need isolated runs should use fresh output paths.

## 5. Comparison and reproducibility

The ordinary comparison path uses exact finding IDs. A conservative alternative groups by rule and evidence-section anchors; unequal or ambiguous groups become `unmatched`, while a single unambiguous leftover pair is `changed`. This avoids silently converting ambiguity into an apparent fixed or newly introduced issue.

Replay strengthens stored-artifact trust. With both selected Markdown sources supplied, the gate regenerates canonical JSONL and requires exact agreement with each stored artifact before evaluating violations. Missing a replay source or any canonical disagreement produces a closed gate result. This proves self-consistency with the current Bend analyzer, not parity with earlier implementations or any external converter.

## 6. Roadmap

### Completed: deterministic Markdown core

- Markdown block extraction with evidence spans in UTF-8 bytes.
- Pure UTF-8 SHA-256 and deterministic evidence/finding identity.
- Exact rational metric representation and fixed-point ARI formatting.
- Twelve mechanical rule families, report rendering, compact findings JSONL, and compact manifest output.
- Direct and conservative finding comparison, replay verification, and a narrow allowlisted gate.
- Artifact write ordering with a completion marker.
- Provider-neutral contextual subprocess integration with evidence-verified candidate admission and reviews.
- Seven machine-checked laws in `LAWS.bend` discharged by `PROOF.bend`.

### Completed: synthetic Markdown emission regression

The frozen `fixtures/corpus` suite validates document hashes, routes, and the
complete expected mechanical-rule emission set. Nine cases positively exercise
ten rule families and include route and clean controls. The two terminology
rules remain unassessed because the Markdown extractor does not produce their
term block tags. These implementation-authored labels test deterministic
regression behavior; they are not independent defect judgments.

### Next: independent content evaluation

Obtain independently reviewed Markdown labels before assessing false positives,
misses, or rule usefulness. Define the supported Markdown and Unicode
boundaries, keep neutral observations distinct from defects, and do not tune on
held-out documents. Extend the extractor first if terminology rules need
positive source-level evaluation.

The contextual stage now parses provider-neutral subprocess candidates,
re-verifies cited source evidence, applies reviews, and merges admitted
candidates into artifacts. Its next step is an independent reviewer study of
citation accuracy, agreement, repeatability, cost, and abstention behavior—not
additional transport-specific scaffolding.

### Deferred: reader-outcome evidence

Claims about improved comprehension require independently designed reader studies or similarly direct outcome evidence. Mechanical counts, lexical overlap, model agreement, and source-level regression detection are not substitutes for that evidence.

## 7. Acceptance discipline

A roadmap item is complete only when its claimed observable behavior is exercised and its limits are recorded. For the current core, the executable smoke programs and `bend PROOF.bend` provide implementation evidence. For future adapters, contextual judgment, format conversion, and surfaces, the acceptance evidence must test the actual path rather than infer success from source inspection or a rendered report.
