# Builds hitter event-probability profiles from plate appearance outcome counts
# This file handles sample-size shrinkage and creates the inputs used by the simulator

library(dplyr)
library(readr)

safe_divide <- function(x, y) {
  ifelse(y > 0, x / y, NA_real_)
}

event_columns <- c("bb", "hbp", "single", "double", "triple", "hr", "out")

check_hitter_counts <- function(hitter_counts) {
  required_cols <- c("player", "pa", event_columns)
  missing_cols <- setdiff(required_cols, names(hitter_counts))

  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  if (any(hitter_counts$pa <= 0, na.rm = TRUE)) {
    stop("Every hitter needs a positive PA value.")
  }

  counted_pa <- hitter_counts %>%
    mutate(counted_pa = rowSums(across(all_of(event_columns)), na.rm = TRUE))

  bad_rows <- counted_pa %>%
    filter(counted_pa != pa)

  if (nrow(bad_rows) > 0) {
    stop(
      "For each hitter, PA should equal bb + hbp + single + double + triple + hr + out. ",
      "Check: ", paste(bad_rows$player, collapse = ", ")
    )
  }

  invisible(TRUE)
}

read_hitter_counts <- function(path) {
  hitter_counts <- read_csv(path, show_col_types = FALSE)
  check_hitter_counts(hitter_counts)
  hitter_counts
}

shrink_event_rate <- function(player_count, player_pa, team_rate, prior_pa) {
  (player_count + prior_pa * team_rate) / (player_pa + prior_pa)
}

build_hitter_profiles <- function(hitter_counts, prior_pa = 25) {
  check_hitter_counts(hitter_counts)

  team_totals <- hitter_counts %>%
    summarize(
      across(all_of(event_columns), sum, na.rm = TRUE),
      pa = sum(pa, na.rm = TRUE)
    )

  team_rates <- team_totals %>%
    mutate(across(all_of(event_columns), ~ .x / pa))

# Raw player rates can be noisy, especially for hitters with limited PA
# Shrinking each player's event rates toward the team average keeps small samples
# from driving the lineup recommendation too aggressively
  
  profiles <- hitter_counts %>%
    mutate(
      p_bb = shrink_event_rate(bb, pa, team_rates$bb, prior_pa),
      p_hbp = shrink_event_rate(hbp, pa, team_rates$hbp, prior_pa),
      p_1b = shrink_event_rate(single, pa, team_rates$single, prior_pa),
      p_2b = shrink_event_rate(double, pa, team_rates$double, prior_pa),
      p_3b = shrink_event_rate(triple, pa, team_rates$triple, prior_pa),
      p_hr = shrink_event_rate(hr, pa, team_rates$hr, prior_pa),
      p_out = shrink_event_rate(out, pa, team_rates$out, prior_pa)
    ) %>%
    normalize_event_probs() %>%
    mutate(
      obp = p_bb + p_hbp + p_1b + p_2b + p_3b + p_hr,
      slg_proxy = p_1b + 2 * p_2b + 3 * p_3b + 4 * p_hr,
      run_value = 0.33 * p_bb +
        0.33 * p_hbp +
        0.47 * p_1b +
        0.77 * p_2b +
        1.04 * p_3b +
        1.40 * p_hr -
        0.27 * p_out
    ) %>%
    arrange(desc(run_value))

  profiles
}

normalize_event_probs <- function(profiles) {
  prob_cols <- c("p_bb", "p_hbp", "p_1b", "p_2b", "p_3b", "p_hr", "p_out")

  profiles %>%
    mutate(prob_sum = rowSums(across(all_of(prob_cols)), na.rm = TRUE)) %>%
    mutate(
      across(
        all_of(prob_cols),
        ~ ifelse(prob_sum > 0, .x / prob_sum, 0)
      ),
      p_out = ifelse(prob_sum > 0, p_out, 1)
    ) %>%
    select(-prob_sum)
}
