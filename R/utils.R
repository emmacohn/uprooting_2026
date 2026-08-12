create_parquet <- function(data, file, ...) {
  arrow::write_parquet(data, file, ...)
  invisible(file)
}

derive_state_abb <- function(microdata) {
  fips <- unique(as.integer(haven::zap_labels(microdata$pwstate)))
  if (length(fips) != 1) {
    stop("microdata must be filtered to a single pwstate to derive a state abbreviation")
  }
  tolower(state_geocodes$state_abb[state_geocodes$state_fips == fips])
}
