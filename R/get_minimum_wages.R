get_state_minimum_wages_2025 <- function(data) {
  data |>
    inner_join(state_geocodes, by = join_by(state_abb)) |>
    transmute(
      pwstate = state_fips,
      date = ym("2025m7"),
      stmin,
      tipmin
    )
}

get_local_minimum_wages_2025 <- function(data, local_area_pwpumas) {
  data |>
    inner_join(state_geocodes, by = join_by(state == state_abb)) |>
    inner_join(
      local_area_pwpumas,
      by = join_by(state, substate_area),
      relationship = "one-to-many"
    ) |>
    transmute(
      pwstate = state_fips,
      pwpuma,
      date = ym("2025m7"),
      localmin,
      localtipmin
    )
}
