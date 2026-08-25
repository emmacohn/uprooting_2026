# Ports the racec/worker/tipc construction from clean_acs.do
# (Economic/min_wage_sim data prep, ecohn/minimum_wage/wi_mw_2026/clean_acs.do)
prepare_acs_microdata <- function(file) {
  data <- read_dta(file) |>
    rename(hrwage = hrwage2, perwt = perwt2)

  data <- data |>
    mutate(
      racec = case_when(
        hispan == 0 & race == 1 ~ 1,
        hispan == 0 & race == 2 ~ 2,
        hispan >= 1 & hispan <= 4 ~ 3,
        hispan == 0 & race >= 4 & race <= 6 ~ 4,
        hispan == 0 & (race == 3 | race > 6) ~ 5
      ),
      worker = age >= 16 &
        !is.na(hrwage) & hrwage > 0 &
        classwkrd >= 22 & classwkrd <= 28 &
        empstatd >= 10 & empstatd <= 12,
      region = case_when(
        pwstate %in% c(12,13,37,45,51,54,1,21,28,47,5,22,40,48) ~ "South",
        TRUE ~ "not South"
      )
    ) |>
    filter(worker) |>
    mutate(
      tipc = case_when(
        occ %in% c(4120, 4130) & ind %in% c(8580, 8590, 8660, 8670, 8680, 8690) ~ 1,
        occ %in% c(4040, 4060, 4110, 4400) ~ 1,
        .default = 0
      )
    ) |>
    select(-worker)

  data
}
