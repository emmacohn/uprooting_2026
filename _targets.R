#tar_load_globals() #-- targets shortcuts incoming from ben
# tar_workspace() an errored target 

source("packages.R")
tar_source()

## pipeline
## targets must end in a target object like tar_target()
tar_assign({
  state_mw_2025_raw = "./input/state_mw_2025m7.csv" |> # update by hand with current status as of X date
    tar_csv_read()

  state_mw_2025 = get_state_minimum_wages_2025(state_mw_2025_raw) |>
    tar_target()

  state_mw_projections_raw = "/projects/ecohn/min_wage_new/projected_minimum_wages/output/state_mw_projections.csv" |> # generated in project_minimum_wages repo
    tar_csv_read()

  state_mw_projections = state_mw_projections_raw |>
    inner_join(state_geocodes, by = join_by(state == state_abb)) |>
    select(
      pwstate = state_fips,
      date,
      stmin = regular_mw,
      tipmin = tipped_mw
    ) |>
    bind_rows(state_mw_2025) |>
    arrange(pwstate, date) |>
    tar_target()

  cbo_projections_file = "./input/51135-2026-02-Economic-Projections.xlsx" |> ## grab this from CBO website
    tar_file()

  cbo_eci_quarterly_projections = get_cbo_eci_quarterly_projections(
    cbo_projections_file
  ) |>
    tar_target()

  cbo_eci_annual_projections = get_cbo_eci_annual_projections(
    cbo_projections_file
  ) |>
    tar_target()

  cbo_cpi_annual_projections = get_cbo_cpi_annual_projections(
    cbo_projections_file
  ) |>
    tar_target()

  eci_policy_projections = cbo_eci_quarterly_projections |>
    mutate(quarter = quarter(date), year = year(date)) |>
    filter(quarter %in% c(2, 3)) |>
    summarize(eci = mean(eci), .by = year) |>
    mutate(date = ym(paste(year, 7))) |>
    select(date, eci) |>
    tar_target()

  step_wage_projections = eci_policy_projections |>
    filter(year(date) %in% 2025:2030) |> #### UPDATE THIS EVERY YEAR ####
    arrange(date) |>
    mutate(step = row_number() - 1) |>
    mutate(cf_nominal_wage_growth = eci / lag(eci) - 1) |>
    select(step, date, cf_nominal_wage_growth) |>
    tar_target()

  acs_data = "./input/acs_state_cps_2025_dist.dta" |>
    prepare_acs_microdata() |>
    filter(region == "South") |> #### UPDATE THIS FOR EACH STATE MW ## region == "South"; pwstate == x
    create_parquet("./input/acs_state_cps_2025.parquet") |>    # read in with haven, convert to parquet w arrow
    tar_parquet_read()

  ### comment out when doing region
  #state_abb = acs_data |>
  #  derive_state_abb() |>
  #  tar_target()

  policy_schedule = tibble( #### UPDATE THIS FOR EACH STATE MW ####
    step = 0:5,
    date = seq(ymd("2025 July 1"), ymd("2030 July 1"), by = "1 year"),
    new_mw = c(NA, 12.00, 13.50, 15.50, 17.50, 20),
    new_tw = c(NA, 12.00, 13.50, 15.50, 17.50, 20)
  ) |>
    tar_target()

  population_projections = tibble(
    racec = 1:5,
    growthann = rep(1, 5)
  ) |>
    tar_target()

  # ADDED BY CLAUDE: holds each state's July 2025 rate flat across the policy_schedule dates,
  # so the July 2026 step increase to $14 is attributed entirely to new_mw/new_tw
  # in policy_schedule rather than already being baked into the baseline
  state_mw_baseline = policy_schedule |>
    distinct(date) |>
    tidyr::crossing(state_mw_2025 |> select(-date)) |>
    select(pwstate, date, stmin, tipmin) |>
    tar_target()

  mw_simulation = mw_simulate(
    acs_data, ## ask Ben how to generate this (use Stata output for now)
    policy_schedule = policy_schedule,
    state_mw = state_mw_projections, #normally state_mw_projections; state_mw_baseline works for pre-planned
    wage_growth = step_wage_projections,
    population_projections = population_projections
  ) |>
    tar_parquet()

  cpi_deflator = cbo_cpi_annual_projections |> #### UPDATE THIS EACH YEAR ####
    filter(year %in% c(2026, 2030)) |>
    pivot_wider(names_from = year, names_prefix = "cpi", values_from = cpi) |>
    mutate(deflator = cpi2026 / cpi2030) |>
    pull(deflator) |>
    tar_target()

 # state_results = make_state_results_table(
 #   mw_simulation,
 #   cpi_deflator,
 #   "output/table_appendix_1.csv"
 # ) |>
 #   tar_csv_read()

  state_summary_results = make_state_summary_table(
    mw_simulation,
    cpi_deflator,
    paste0("output/", 
   # state_abb, ##comment out if using region instead of pwstate
    "south_table_1_v2.csv")
  ) |>
    tar_csv_read()

})
