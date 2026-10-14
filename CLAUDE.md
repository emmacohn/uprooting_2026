# uprooting_2026

`targets` pipeline that runs EPI's minimum wage simulation for the Uprooting 2026 analysis: a South region (or single-state) minimum wage increase to $20 by July 2030 (`policy_schedule` in `_targets.R`).

## Harmonization goal

We are harmonizing two implementations of the minimum wage model so they produce the same results:

| | Stata model (old) | R model (new) |
|---|---|---|
| Location | `/projects/ecohn/minimum_wage/` (current run: `modeling_2026/`) | `/projects/ecohn/min_wage_new/` |
| Simulation engine | `min_wage_sim/` ado (`mwsim`), driven by `modeling_2026/master.do` → `run_models.do` | `mwsimulator` R package (`min_wage_new/mwsimulator/`, see its `CLAUDE.md`) |
| ACS cleaning | `modeling_2026/clean_acs.do` | `min_wage_new/acs_min_wage_prep/stata/clean_acs.do` (Stata, run from a `targets` pipeline) |
| ACS input | `minimum_wage/substate_geo/` → `data/output/acs_state_cps_2025_dist.dta` | `acs_min_wage_prep/` → `inputs_clean/clean_acs_state_base.parquet` |
| MW projections | `modeling_2026/clean_state_mw.do`, `create_policy_schedule.do` | `min_wage_new/projected_minimum_wages/` → `output/state_mw_projections.csv` |

Copies of both ACS files live in `input/`. `acs_min_wage_prep/stata/clean_acs.do` is a port of `modeling_2026/clean_acs.do`, minus the minimum-wage merges. The differences between them are listed below.

## This pipeline

- `_targets.R`: the pipeline. Lines marked `#### UPDATE THIS ... ####` must be edited for each run (state/region filter, policy schedule, CBO years, output file name).
- `R/prepare_acs_microdata.R`: cleans the **substate_geo** `.dta` (renames `hrwage2`/`perwt2`, builds `racec`, `worker`, `region`, `tipc`). It is not needed when reading the acs_min_wage_prep parquet, which already has these variables.
- `R/make_results_tables.R`: `prep_demographics()` expects `sex`, `age`, `racec`, `ftotinc`, `parttime`. `make_state_summary_table()` writes `output/*_table_1*.csv`.
- Run with `targets::tar_make()`. Check the pipeline parses with `targets::tar_manifest()`.

### Current state (2026-10-14)

- `acs_data_all` reads `/projects/ecohn/min_wage_new/acs_min_wage_prep/inputs_clean/clean_acs_state_base.parquet` directly. `acs_data` filters `region == 1`. In the parquet, `region` is a labelled 0/1, **not** the string `"South"`.
- The South filter gives 2,204,286 rows. Everywhere else there are 4,393,358 rows.
- `acs_min_wage_prep/stata/clean_acs.do` now creates and keeps `sex`, `ftotinc` and `parttime` (`gen parttime = uhrswork <= 34`), which `prep_demographics()` needs. The pipeline runs end to end.
- The previous input was `input/acs_state_cps_2025.parquet`, the substate_geo `.dta` after `prepare_acs_microdata()` and the South filter. Its results are the committed version of `output/south_table_1_v3.csv` (`git show HEAD:output/south_table_1_v3.csv`).
- **No decision yet** on harmonizing `tipc` or the CPS wage target (see the open items below). Don't change either without asking.

## ACS input file differences

**substate_geo**: `minimum_wage/substate_geo/master.do` → `create_acs_prep.do` → `create_acs_state.do`, which writes `acs_state_cps_2025_dist.dta`.
**acs_min_wage_prep**: `prep_acs.do` → `acs_state.do` → `clean_acs.do` → `R/dta_to_parquet()`, which writes `clean_acs_state_base.parquet`.

### Wage and weight construction (affects results)

| Step | substate_geo | acs_min_wage_prep |
|---|---|---|
| Weeks worked (`adj_wkswork1`) | regression-predicted from CPS ASEC within `wkswork2` bins (`impute_weeksworked.do`) | bin midpoint (= `adj_wkswork0`) |
| `hrwage1` | mean of `hrwage0` and a CPS ORG 2015–19 log-wage regression prediction, run separately by sex (`impute_wages_cpsreg.do`) | `= hrwage0`, no regression |
| `hrwage2` (final wage) | state percentile-matched to 2025 CPS ORG `wageotc`, **all** wages | same method, but drops CPS wages that were imputed (`a_earnhour`/`a_weekpay`) |
| Weights | `perwt2` raked (ipfraking) to ACS 2019 5-yr tables of employment by age, race, Hispanic origin and education | `perwt2 = perwt0`, no raking |
| Weight scaling | none in file. The Stata model's `clean_acs.do` scales one state's `perwt2` to that state's CPS ORG wage-earner count (2025m9–2026m8, ÷11, excluding self-employed). `prepare_acs_microdata()` here does **not** scale. | national total scaled to the 2025 CPS ORG wage-earner count, ÷11 months (`cps_emp_benchmark.do`) |
| Sample | drops `classwkr == 1` and `pwstate > 56` | keeps `classwkrd` 22–28, drops `pwstate > 56` |
| Final names | `hrwage2`, `perwt2` (renamed to `hrwage`/`perwt` in `prepare_acs_microdata()`) | `hrwage0`, `perwt0` → renamed to `hrwage`/`perwt` in `dta_to_parquet()` |

### Created variables

| Variable | substate_geo `.dta` (+ `prepare_acs_microdata()`) | acs_min_wage_prep parquet | Stata model `modeling_2026/clean_acs.do` |
|---|---|---|---|
| `sex` | raw IPUMS (1 = male, 2 = female) | was dropped after making `female`; now kept | dropped after making `female` |
| `female` | not kept | 0/1 from `sex` | 0/1 from `sex` |
| `parttime` | `uhrswork <= 34` (from `impute_wages_cpsreg.do`) | was absent; now `uhrswork <= 34` | not created |
| `hourc` | absent | 0 = <20, 1 = 20–34, 2 = 35+ hrs | same (`irecode`) |
| `ftotinc` | raw (9999999 = N/A, negatives kept) | 9999999 → `.`, negatives → 0; was dropped, now kept | same cleaning |
| `faminc` | absent | 0–5: <25k, 25–50k, 50–75k, 75–100k, 100–150k, 150k+ | same |
| `racec` | built in `prepare_acs_microdata()` | same 5-group definition | same |
| `region` | string `"South"`/`"not South"` | labelled 0/1 (1 = South) | not created |
| **`tipc`** | narrow: occ 4120/4130 × ind 8580–8690; occ 4040/4060/4110/4400 | **broad**: also ind 8970–9090 and occ 4500/4510/4520/4521/4522/4525 (barbers, hairdressers) | **narrow**, with the broad codes commented out. Matches substate_geo/`prepare_acs_microdata()`, **not** acs_min_wage_prep |
| `worker` | filter, then dropped | asserted all 1, kept | filter (`drop if worker == 0`) |
| `teens`, `agec`, `poc`, `edc`, `childc`, `povstat`, `sectc`, `indc` | absent | present | present |
| `vetc` | absent (`vetstatd` raw) | created but not in `keep` | created and kept |
| `majorind`, `majorocc` | present | absent | absent |
| Stata model only | n/a | n/a | `native_american`, `restaurant_wrkr`, `ag_wrkr`, `divisionXindc`, merged state/local MW steps |

`prep_demographics()`'s groups map onto acs_min_wage_prep variables exactly:
- `sex == 2` ↔ `female == 1`
- `parttime == 1` ↔ `hourc %in% c(0, 1)`
- income groups <50k / 50–99k / 100k+ ↔ `faminc` 0–1 / 2–3 / 4–5

## Effect on results: South, $20 by 2030

On 2026-10-14, switching the input from substate_geo to acs_min_wage_prep raised the South's total annual wage change from **$88.4B to $105.4B** (+$17.0B, +19%). Policy, wage growth and MW projections were the same in both runs. The decomposition below comes from running `mw_simulate()` / `mw_analyze(by = "tipc")` on each input outside the pipeline. The old-input run reproduced the committed table exactly ($88,378,538,971).

| | substate_geo (old) | acs_min_wage_prep (new) | Diff |
|---|---|---|---|
| Total workforce | 50.35M | 49.62M | −0.73M |
| Total affected | 16.50M | 16.99M | +0.49M |
| Avg annual wage change | $5,357 | $6,202 | +16% |
| **Total annual wage change** | **$88.4B** | **$105.4B** | **+$17.0B** |
| … non-tipped (`tipc == 0`) | $67.0B | $80.2B | +$13.1B (77% of gap) |
| … tipped (`tipc == 1`) | $21.3B | $25.2B | +$3.8B (23% of gap) |
| Tipped workforce | 1.12M | 1.41M | +0.28M |
| Avg raise, affected tipped | $19,251 | $18,022 | |
| Avg raise, affected non-tipped | $4,356 | $5,142 | +18% |
| Total with everyone `tipc = 0` | $72.5B | $85.2B | +$12.8B |

**Tipped workers (+$3.8B).** The broader acs_min_wage_prep `tipc` definition adds about 280k tipped workers in the South. Each one is expensive because this policy sets `new_tw = new_mw = $20`. The tipped raise is `prop_tw - tipmin`, which is about $17.87/hr where the tipped minimum is $2.13, so an affected tipped worker gets roughly 4× the raise of a non-tipped worker. On this point the old file matches the Stata model; the new one doesn't.

**Lower wage distribution (+$13.1B, the main driver).** The new file has more workers further below $20:

| South, weighted | old | new |
|---|---|---|
| p10 / p20 / p30 hourly wage | $13.65 / $16.08 / $18.76 | $13.08 / $15.84 / $18.26 |
| Share below $15 | 15.1% | 16.6% |
| Share below $20 | 35.6% | 36.4% |
| Mean gap to $20 among those below $20 | $4.81 | $5.02 |
| Mean usual hours | 39.7 | 39.7 |

Untested candidate causes, from the "Wage and weight construction" table above:
1. **The CPS wage target excludes imputed wages** in `acs_min_wage_prep/stata/impute_wages_cpsloc.do`. This is the most likely cause, because it directly moves the state percentiles that ACS wages are matched to.
2. **No CPS-regression averaging** in `hrwage1`, which changes who ends up at the bottom of each state's distribution.
3. **No raking of `perwt2`**, which changes the weighted mix of workers at each wage level.

A smaller workforce (−0.73M, from the different weight scaling) slightly offsets these.

### Open harmonization items (no changes made; awaiting decision)

- **`tipc` definition**: decide whether acs_min_wage_prep should use the narrow definition used by the Stata model. That accounts for about $3.8B of the South gap.
- **CPS wage target**: decide whether to keep imputed CPS wages in `impute_wages_cpsloc.do`, as substate_geo does. Testing that is the quickest way to explain the remaining non-tipped gap.
- **Wage imputation and raking**: acs_min_wage_prep drops the CPS regression step, the weeks-worked regression and the raking. Confirm this is intended before comparing results against the Stata model.
- **Weight scaling target**: the Stata model scales per state, over the window 2025m9–2026m8. acs_min_wage_prep scales nationally to calendar 2025. With the old `.dta` path, this pipeline applies no scaling.
