## Suppression rules (matching mw_export defaults):
##   counts/shares suppressed when total_affected < 1500,
##                              or share_affected < 0.006,
##                              or n_workforce  < 1500
##   wage stats suppressed when n_affected < 500

suppression_thresholds <- list( ## may want to edit this
  min_total_affected = 1500,
  min_share_affected = 0.006,
  min_total_directly_affected = 500,
  min_share_directly_affected = 0.003,
  min_total_indirectly_affected = 500,
  min_share_indirectly_affected = 0.003,
  min_n_workforce = 1500,
  min_n_affected = 500
)

apply_manual_suppression <- function(analysis) {
  thr <- suppression_thresholds

  count_share_cols <- c(
    "total_workforce",
    "total_directly_affected",
    "share_directly_affected",
    "total_indirectly_affected",
    "share_indirectly_affected",    
    "total_affected",
    "share_affected",
    "share_of_total_affected"
  )
  wage_cols <- c("avg_annual_wage_change", "total_annual_wage_change")

  result <- analysis |>
    mutate(
      .reason_low_total = !is.na(total_affected) &
        total_affected < thr$min_total_affected,
      .reason_low_share = !is.na(share_affected) &
        share_affected < thr$min_share_affected,
      .reason_low_total_directly_affected = !is.na(total_directly_affected) &
        total_directly_affected < thr$min_total_directly_affected,
      .reason_low_share_directly_affected = !is.na(share_directly_affected) &
        share_directly_affected < thr$min_share_directly_affected,
      .reason_low_total_indirectly_affected = !is.na(total_indirectly_affected) &
        total_indirectly_affected < thr$min_total_indirectly_affected,
      .reason_low_share_indirectly_affected = !is.na(share_indirectly_affected) &
        share_indirectly_affected < thr$min_share_indirectly_affected,
      .reason_low_n_workforce = n_workforce < thr$min_n_workforce,
      .reason_low_n_affected = n_affected < thr$min_n_affected,
      .suppress_counts = .reason_low_total | .reason_low_share |
        .reason_low_total_directly_affected | .reason_low_share_directly_affected |
        .reason_low_total_indirectly_affected | .reason_low_share_indirectly_affected |
        .reason_low_n_workforce,
      .suppress_wages = .reason_low_n_affected
    )

  for (col in count_share_cols) {
    result[[col]][result$.suppress_counts] <- NA_real_
  }
  for (col in wage_cols) {
    result[[col]][result$.suppress_wages] <- NA_real_
  }

  reason_text <- function(low_total, low_share, low_total_directly_affected, 
    low_share_directly_affected, low_total_indirectly_affected, low_share_indirectly_affected, low_n_wf, low_n_aff) {
    parts <- c(
      if (isTRUE(low_total)) {
        sprintf("total affected < %s", thr$min_total_affected)
      },
      if (isTRUE(low_share)) {
        sprintf("share affected < %.1f%%", 100 * thr$min_share_affected)
      },
      if (isTRUE(low_total_directly_affected)) {
        sprintf("total direct < %s", thr$min_total_directly_affected)
      },
      if (isTRUE(low_share_directly_affected)) {
        sprintf("share direct < %.1f%%", 100 * thr$min_share_directly_affected)
      },
      if (isTRUE(low_total_indirectly_affected)) {
        sprintf("total indirect < %s", thr$min_total_indirectly_affected)
      },
      if (isTRUE(low_share_indirectly_affected)) {
        sprintf("share indirect < %.1f%%", 100 * thr$min_share_indirectly_affected)
      },
      if (isTRUE(low_n_wf)) {
        sprintf("workforce sample size < %s", thr$min_n_workforce)
      },
      if (isTRUE(low_n_aff)) {
        sprintf("affected sample size < %s", thr$min_n_affected)
      }
    )
    if (length(parts) == 0) NA_character_ else paste(parts, collapse = "; ")
  }

  result$suppression_note <- pmap_chr(
    list(
      result$.reason_low_total,
      result$.reason_low_share,
      result$.reason_low_total_directly_affected,
      result$.reason_low_share_directly_affected,
      result$.reason_low_total_indirectly_affected,
      result$.reason_low_share_indirectly_affected,
      result$.reason_low_n_workforce,
      result$.reason_low_n_affected
    ),
    reason_text
  )

  result |>
    select(-starts_with(".reason_"), -starts_with(".suppress_"))
}

prep_demographics <- function(simulation) {
  sex <- as.integer(zap_labels(simulation$sex))
  age <- as.integer(zap_labels(simulation$age))
  race <- as.integer(zap_labels(simulation$racec))
  ftotinc <- as.numeric(zap_labels(simulation$ftotinc))
  parttime <- as.integer(zap_labels(simulation$parttime))

  simulation$gender_grp <- case_when(
    sex == 1 ~ "Men",
    sex == 2 ~ "Women"
  )

  simulation$age_grp <- case_when(
    age <= 19 ~ "Age 19 or younger",
    age >= 20 ~ "Age 20 or older"
  )

  simulation$race_grp <- case_when(
    race == 1 ~ "White",
    race == 2 ~ "Black",
    race == 3 ~ "Hispanic",
    race == 4 ~ "AAPI",
    race == 5 ~ "Other"
  )

  simulation$faminc_grp <- case_when(
    ftotinc == 9999999 ~ NA_character_, # IPUMS N/A code for total family income
    ftotinc < 50000 ~ "Less than $50,000",
    ftotinc < 100000 ~ "$50,000-$99,999",
    ftotinc >= 100000 ~ "$100,000 or more"
  )

  simulation$hours_grp <- case_when(
    parttime == 1 ~ "Part-time",
    parttime == 0 ~ "Full-time"
  )

  simulation
}

format_count_thousands <- function(x) {
  ifelse(
    is.na(x),
    NA_character_,
    label_comma(accuracy = 1)(round(x / 1e3) * 1e3)
  )
}

format_share <- function(x) {
  ifelse(is.na(x), NA_character_, label_percent(accuracy = 0.1)(x))
}

format_dollars_hundreds <- function(x) {
  ifelse(
    is.na(x),
    NA_character_,
    label_dollar(accuracy = 1)(round(x / 100) * 100)
  )
}

format_dollars_tens <- function(x) {
  ifelse(
    is.na(x),
    NA_character_,
    label_dollar(accuracy = 1)(round(x / 10) * 10)
  )
}

select_results_columns <- function(data, group_label) {
  data |>
    transmute(
      "{group_label}" := group,
      `Total workforce` = format_count_thousands(total_workforce),
      `Total directly affected` = format_count_thousands(total_directly_affected),
      `Share of directly affected` = format_share(share_directly_affected),
      `Total indirectly affected` = format_count_thousands(total_indirectly_affected),
      `Share of indirectly affected` = format_share(share_indirectly_affected),
      `Total affected` = format_count_thousands(total_affected),
      `Share of group affected` = format_share(share_affected),
      `Group share of total affected` = format_share(share_of_total_affected),
      `Average annual wage change` = format_dollars_tens(avg_annual_wage_change),
      `Total annual wage change` = format_dollars_hundreds(total_annual_wage_change),      
      suppression_note = suppression_note
    )
}

section_header_row <- function(label, group_col) {
  tibble(
    "{group_col}" := label,
    `Total workforce` = NA_character_,
    `Total directly affected` = NA_character_,
    `Share of directly affected` = NA_character_,
    `Total indirectly affected` = NA_character_,
    `Share of indirectly affected` = NA_character_,
    `Total affected` = NA_character_,
    `Share of group affected` = NA_character_,
    `Group share of total affected` = NA_character_,
    `Average annual wage change` = NA_character_,
    `Total annual wage change` = NA_character_,
    suppression_note = NA_character_,
    .is_section_header = TRUE
  )
}

run_analysis <- function(simulation, by_col, keep_groups, deflator) {
  result <- mw_analyze(simulation, by = by_col, deflator = deflator) |>
    apply_manual_suppression() |>
    select_results_columns(group_label = "group")

  result <- result |>
    filter(group %in% keep_groups) |>
    mutate(group = factor(group, levels = keep_groups)) |>
    arrange(group) |>
    mutate(group = as.character(group))

  result
}

make_state_summary_table <- function(
  mw_simulation,
  cpi_deflator,
  file = "state_summary_results.csv"
) {
  sim <- prep_demographics(mw_simulation)

  overall <- mw_analyze(sim, deflator = cpi_deflator) |>
    apply_manual_suppression() |>
    select_results_columns(group_label = "group") |>
    rename(Group = group) |>
    mutate(Group = "All workers", .is_section_header = FALSE)

  build_section <- function(label, by_col, keep_groups) {
    bind_rows(
      section_header_row(label, "group"),
      run_analysis(sim, by_col, keep_groups, deflator = cpi_deflator) |>
        mutate(.is_section_header = FALSE)
    ) |>
      rename(Group = group)
  }

  gender_section <- build_section(
    "Gender",
    "gender_grp",
    c("Men", "Women")
  )

  age_section <- build_section(
    "Age",
    "age_grp",
    c("Age 19 or younger", "Age 20 or older")
  )

  race_section <- build_section(
    "Race/ethnicity",
    "race_grp",
    c("AAPI", "Black", "Hispanic", "White")
  )

  faminc_section <- build_section(
    "Family income",
    "faminc_grp",
    c("Less than $50,000", "$50,000-$99,999", "$100,000 or more")
  )

  hours_section <- build_section(
    "Work hours",
    "hours_grp",
    c("Part-time", "Full-time")
  )

  result <- bind_rows(
    overall,
    gender_section,
    age_section,
    race_section,
    faminc_section,
    hours_section
  ) |>
    select(-.is_section_header) |>
    select(-suppression_note) |>
    filter(!is.na(`Total workforce`)) |>
    mutate(across(`Average annual wage change`, ~ str_replace(.x, "\\$", "")),
           across(`Total annual wage change`, ~ str_replace(.x, "\\$", "")),
  )

  write_csv(result, file)
  invisible(file)
}

make_state_results_table <- function(
  mw_simulation,
  cpi_deflator,
  file = "state_results.csv"
) {
  sim <- mw_simulation
  sim$state_grp <- as.integer(sim$statefips)

  overall <- mw_analyze(sim, deflator = cpi_deflator) |>
    apply_manual_suppression() |>
    select_results_columns(group_label = "group") |>
    rename(State = group) |>
    mutate(State = "U.S. total")

  state_lookup <- state_geocodes |>
    select(state_fips, state_name) |>
    mutate(state_fips = as.integer(state_fips))

  by_state <- mw_analyze(sim, by = "state_grp", deflator = cpi_deflator) |>
    apply_manual_suppression() |>
    select_results_columns(group_label = "group") |>
    mutate(state_fips = as.integer(group)) |>
    inner_join(state_lookup, by = join_by(state_fips)) |>
    arrange(state_name) |>
    transmute(
      State = state_name,
      `Total workforce`,
      `Total directly affected`,
      `Share of directly affected`,
      `Total indirectly affected`,
      `Share of indirectly affected`,
      `Total affected`,
      `Share of group affected`,
      `Group share of total affected`,
      `Average annual wage change`,
      `Total annual wage change`,
      suppression_note
    )

  result <- bind_rows(overall, by_state) |>
    select(-suppression_note) |>
    mutate(across(`Average annual wage change`, ~ str_replace(.x, "\\$", "")))

  write_csv(result, file)
  invisible(file)
}
