make_historical_minimum_wage_figure = function(file_name) {
  cpi_data = c_cpi_u_extended_monthly_nsa |>
    filter(year < 1947) |>
    bind_rows(c_cpi_u_extended_monthly_sa) |>
    mutate(date = ym(paste(year, month))) |>
    select(date, cpi = c_cpi_u_extended)

  cpi_base = cpi_data |>
    filter(date == max(date)) |>
    pull(cpi)

  us_minimum_wage_monthly |>
    mutate(date = ym(paste(year, month))) |>
    inner_join(cpi_data, by = "date") |>
    mutate(real_minimum_wage = minimum_wage * cpi_base / cpi) |>
    select(date, value = real_minimum_wage) |>
    create_csv(file_name)
}
