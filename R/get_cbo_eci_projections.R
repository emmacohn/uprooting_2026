get_cbo_eci_quarterly_projections <- function(cbo_projections_file) {
  raw <- read_excel(
    cbo_projections_file,
    sheet = "1. Quarterly",
    col_names = FALSE
  )

  quarters <- as.character(unlist(raw[7, -(1:2)]))
  eci_levels <- as.numeric(unlist(raw[63, -(1:2)]))

  tibble(quarter = quarters, eci = eci_levels) |>
    mutate(date = yq(quarter)) |>
    filter(date >= yq("2025q2")) |>
    select(date, eci)
}

get_cbo_eci_annual_projections <- function(cbo_projections_file) {
  raw <- read_excel(
    cbo_projections_file,
    sheet = "2. Calendar Year",
    col_names = FALSE
  )

  years <- as.integer(unlist(raw[7, -(1:2)]))
  eci_levels <- as.numeric(unlist(raw[63, -(1:2)]))

  tibble(year = years, eci = eci_levels) |>
    filter(!is.na(year), !is.na(eci), year >= 2025)
}

get_cbo_cpi_annual_projections <- function(cbo_projections_file) {
  raw <- read_excel(
    cbo_projections_file,
    sheet = "2. Calendar Year",
    col_names = FALSE
  )

  years <- as.integer(unlist(raw[7, -(1:2)]))
  cpi_levels <- as.numeric(unlist(raw[53, -(1:2)]))

  tibble(year = years, cpi = cpi_levels) |>
    filter(!is.na(year), !is.na(cpi), year >= 2025)
}
