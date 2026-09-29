# Root-Cause Complaint Classification in Base SAS: Methodology (Parts 1 and 2)

Everything here is implemented in the accompanying `.sas` files and mirrored by the workbench app, so each idea can be run and inspected.

## Part 1.1  Separating venting and admin notes from root cause

**Principle: tag before you count.** Noise is removed at sentence level, before any vocabulary is built (step 01).

| Layer | Field | What it catches | How (Base SAS) |
|---|---|---|---|
| ADMIN | findings | Handler notes: "call ref logged", "email sent", "case closed", "forwarded to" | `prxparse` cue list; sentence is dropped from the vocabulary entirely |
| VENT | description | Short, high-emotion sentences with no factual content ("Absolutely disgraceful service!") | Emotion cue **and** 10 words or fewer. Long sentences keep facts, so they stay CUST |
| NOTUP | findings | Rejected aspects: "not upheld", "no evidence", "acted correctly" | Checked **before** UPHELD, because "not upheld" contains "upheld" |
| UPHELD | findings | Business agreed: "upheld", "our error", "should have", "failed because" | Cue list |
| NEUTRAL / CUST | both | Everything else (facts, customer narrative) | Default |

Supporting controls: boilerplate suppression via `max_df_pct` in TF-IDF, one-off typo suppression via `min_df`, negations ("not", "no") kept as tokens so "not made clear" survives as a trigram, and a review queue (`LOW_CONFIDENCE_REVIEW`, `CUSTOMER_VIEW_ONLY`) instead of forced labels.

**Bridging customer and business language.** Customers say "they took money twice"; investigators write "duplicate debit applied". Three measures:
1. Both registers point at the **same L3** through the keyword map: add customer phrasings as extra rows for the business term, never a second taxonomy.
2. Both sides pass through the same lemma map, stemmer and stopword list, so tense, plurals and word order noise disappear.
3. Fuzzy matching (complev/spedis/soundex) absorbs typos and spelling variants; matches are logged (`cmp.match_map`) so you can audit them and promote good ones into the keyword map.

Two label spaces are kept apart on purpose: **root cause** (L1-L3, what went wrong) and **trigger** (T01-T05, why the customer complained). Customer emotion is never allowed to decide the root cause, and business findings never decide the trigger.

## Part 1.2  Dual-field weighting

Each keyword hit is scored, then summed per candidate:

```
hit_score  = kw_weight x match_quality x (0.5 + 0.5 x idf/idf_max) x W(purpose, field, section)
kw_score   = (1 + ln count) / count x sum(hit_score)          -- repeats get diminishing returns
root(L3)   = sum over ROOT keywords of L3     (D and F parts kept separate for audit)
trigger(T) = sum over TRIGGER keywords of T
```

`W` lives in the table `cmp.weight_matrix`, so weights are tuned by editing rows, not code:

| Section | ROOT weight | TRIGGER weight | Reason |
|---|---|---|---|
| Description, factual (CUST) | 0.35 | 1.00 | A pointer to the cause, but the customer's own words are the trigger |
| Description, venting (VENT) | 0.05 | 0.80 | Emotion signal, almost no causal content |
| Findings, UPHELD | **1.00** | 0.20 | The business agreed: strongest cause evidence |
| Findings, NEUTRAL | 0.50 | 0.10 | Fact without a determination |
| Findings, NOTUP | **-0.30** | 0.00 | Evidence this is *not* the cause: subtracts |
| Findings, ADMIN | 0 | 0 | Never evidence |

Worked example (sample 1005, scam): the customer says "no warning" (description, +0.17 towards *Inadequate scam warning*), but the findings say the warning "was appropriate" (NOTUP, -0.30). Net root score is -0.13, so the case is labelled `ALLEGED_NOT_UPHELD` rather than falsely classified. Trigger still comes out as *Financial loss* / *Trust and fairness* from the customer's own words.

**Status logic:** `CLASSIFIED` needs a root score at or above `min_root`, a top-vs-runner-up confidence at or above `min_conf`, **and** positive support from findings. Support from the customer text alone becomes `CUSTOMER_VIEW_ONLY`. Tune the numbers against a hand-labelled sample (200-300 complaints is enough): measure precision per L3 at several `min_root`/`min_conf` values with `PROC SQL`, and choose the abstention level you can tolerate.

## Part 1.3  Simulating an LLM with Base SAS only

What is realistically simulated, and what is not:

| LLM behaviour | Base SAS stand-in | Where |
|---|---|---|
| "Read and label" | Weighted dictionary classification against the 3-level taxonomy | 05 |
| Tolerance to wording and typos | Lemma map, regex stemmer, complev/spedis/soundex fuzzy scoring | 02, 04 |
| Semantic closeness | TF-IDF cosine between complaint and keyword vectors (`cmp.sim_l3`); optionally against centroids of labelled example complaints per L3 (nearest-neighbour "few-shot") | 03, 04 |
| "Explain your answer" | `cmp.class_evidence`: every keyword, count and D/F contribution | 05 |
| "I'm not sure" | Abstention statuses and confidence ratio | 05 |
| Learning from feedback | Analyst fixes flow back as new `kw_map` rows (mine the top TF-IDF terms of mislabelled complaints) | 03, 00b |

Honest limits: no real semantics or long-range negation, recall depends on dictionary coverage, and paraphrase handling is only as good as the synonyms you add. Plan for a **dictionary growth loop**: classify, review the low-confidence queue, add keywords, re-run. If an LLM endpoint later becomes reachable (`PROC HTTP` is part of Base SAS), the same taxonomy tables serve as the label schema and this pipeline provides the shortlist and evidence to send.

## Part 2  Three-level taxonomy schema

```
tax_l1 (PK l1_id) <-- tax_l2 (PK l2_id, FK l1_id) <-- tax_l3 (PK l3_id, FK l2_id)
                                                          ^
tax_trigger (PK trg_id) <-- kw_map (PK kw_id, FK l3_id OR trg_id, by kw_type)
weight_matrix (purpose, field, sect -> w)          stopwords, lemma_map
complaints_raw -> sentences -> ngrams_stem -> tf, df_idf, tfidf -> match_map -> kw_hits -> class_evidence -> complaint_class
```

**Why normalised tables and not one wide path column:** renaming an L2 changes one row; reporting rolls up by joining, not string-splitting; and a keyword can never point at a category that does not exist.

Design rules:
- **Natural, readable, immutable IDs** (`PAY01.1`). Rename the *name*, never the ID; retire with `active_flag`/`valid_to` instead of deleting, so history still resolves.
- **Keyword parent rule:** `kw_type='ROOT'` requires `l3_id`; `'TRIGGER'` requires `trg_id`; enforced by a CHECK constraint (`06_schema_constraints.sas`). One table, two nullable parents, was chosen over two near-identical keyword tables so the matching code is written once.
- **Derived, not stored by hand:** `kw_stem`, `ngram_n`, `kw_sdx` are computed into `cmp.kw_norm` so typed keywords are always normalised by the pipeline itself.
- **Metadata to add as it matures:** `taxonomy_version`, `created_by`, `created_dttm`, `source` (SEED / MINED / ANALYST), `register` (customer / business), and the append-only `cmp.kw_audit`.
- **Results tables:** keep one row per complaint per **run** (`run_id`, `taxonomy_version`, parameters) so classifications stay reproducible after the taxonomy changes.
- **Integrity without a server:** primary keys, foreign keys (`on delete restrict`), CHECK constraints and indexes on SAS datasets, plus the orphan check in `00b`. `cmp.v_taxonomy_path` gives a flat L1 > L2 > L3 view for reports.
