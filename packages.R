## global options
options(epiextractr.quiet = TRUE)
options(tidyverse.quiet = TRUE)
options(epiverse.quiet = TRUE)

## packages
library(conflicted)
library(targets)
library(tarchetypes)
library(tidyverse)
library(epiverse)
library(readxl)
library(mwsimulator)
library(arrow)
library(haven)
library(assertr)
library(MetricsWeighted)
library(scales)

## conflicts
conflicts_prefer(dplyr::filter, dplyr::lag, .quiet = TRUE)
