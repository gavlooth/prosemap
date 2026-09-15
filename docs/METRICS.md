# Implemented mechanical metrics

Prosemap keeps measurements separate from judgments. It does not compute a composite readability score, and no metric by itself establishes comprehension, pedagogical quality, or a CI violation.

All numeric operations in the Bend implementation are deterministic integer operations. Ratios are retained as exact source-count pairs and fixed-point values are calculated without floating point.

## Exact metric representation

`prosemap/types.bend` defines:

```text
Metric = Unassessed | Assessed{num: Nat, den: Nat}
```

`Metric.mk(num, den)` returns `Unassessed` when `den` is zero, otherwise `Assessed{num, den}`. Fractions are deliberately not reduced: `3/12` retains the counts an auditor needs to understand the measurement. Rendered metrics are therefore `num/den` or `unassessed`, never a rounded decimal.

The zero-denominator rule applies even when an empty collection might tempt an implementation to report `0`. The formal `metric_zero_den_unassessed` law proves this constructor behavior, and `cohesion_empty_unassessed` proves it for empty lexical comparisons.

## Lexical cohesion kernel

`prosemap/cohesion.bend` provides a pure token-list comparison kernel. It is available to callers and smoke programs; the top-level `analyze` flow currently emits mechanical findings rather than an adjacent-block cohesion report.

### Tokenization

The tokenizer:

1. lowercases ASCII alphabetic characters;
2. replaces non-alphanumeric characters with spaces;
3. splits on spaces; and
4. drops one-character tokens and a bundled English stop-word list.

It does **not** perform Unicode normalization such as NFKC. That limitation matters for non-ASCII lexical comparisons and is a reason not to generalize the values beyond this implementation.

### Scores

For two token lists, let `A` and `B` be their distinct-token sets. The kernel returns sorted shared terms plus:

- **Jaccard set overlap:** $|A \cap B| / |A \cup B|$.
- **Multiset Dice overlap:** $2\sum_{t \in A \cap B}\min(c_A(t),c_B(t)) / (|L| + |R|)$, where $L$ and $R$ are the original token lists.

Both are exact `Metric` values. A zero union or zero total token count is `Unassessed`. Jaccard measures vocabulary-set overlap; Dice retains repetition through token counts. Neither resolves referents, determines logical continuity, or measures whether a reader understood the transition.

## Automated Readability Index

`prosemap/mechanical.bend` emits a per-section `formula.ari` observation only for mapped prose that meets the default eligibility threshold: at least 100 words and 3 sentences. The calculation is fixed point in hundredths:

$$
100\,\mathrm{ARI} = \left\lfloor\frac{471\,C}{W}\right\rfloor
+ \left\lfloor\frac{50\,W}{S}\right\rfloor - 2143,
$$

where $C$ is the implementation's eligible character count, $W$ its word count, and $S$ its sentence count. The result is formatted as a signed value with two decimal places. Eligibility prevents division by zero and suppresses undersized sections rather than inventing a score.

ARI is a surface statistic under the implementation's English-oriented word and sentence rules. It is an observation, not a defect classification or a statement about reader comprehension; it does not account for terminology, mathematical prerequisites, or conceptual dependency.

## Terminology introduction density

The `terminology.introduction-density` candidate rule measures, per section,

$$
\mathrm{termsPerWords} = \frac{\text{source-evidenced term blocks}}{\text{mapped prose words}}.
$$

A term block is a mapped block whose tag is `strong`, `b`, or `dfn`. The metric is stored exactly using `Metric`; if prose-word count were zero, the helper returns `Unassessed`. The emitted candidate path requires both at least the configured number of term blocks (default 3) and a positive prose-word denominator, so it does not emit an unassessed density candidate.

This is a count of source-marked term blocks, not a semantic terminology inventory. Unmarked definitions, aliases, prerequisite knowledge, the quality of an explanation, and a reader's route through the text are outside its scope.

## Interpretation boundary

The surrounding mechanical rules can flag structural, reference, notation, and source-pattern conditions, but metrics remain descriptive. They are not automatically promoted to severity, a review decision, or a gate failure. The gate has a deliberately narrow rule allowlist; ARI, lexical cohesion, and terminology density are not in it.
