library(dplyr)
library(tibble)
library(tidyr)
library(stringr)
library(purrr)

score_custom_lineup <- function(lineup, optimizer_result, n_sims = 1000, seed = 123) {
  if (length(lineup) != 9) {
    stop("Custom lineup must have exactly 9 hitters.")
  }

  player_pool <- optimizer_result$player_pool

  custom_lineup <- player_pool %>%
    slice(match(lineup, player))

  if (any(is.na(custom_lineup$player))) {
    missing_players <- lineup[is.na(match(lineup, player_pool$player))]
    stop("Could not match: ", paste(missing_players, collapse = ", "))
  }

  custom_lineup <- custom_lineup %>%
    mutate(batting_order = row_number())

  custom_score <- simulate_lineup(
    lineup = custom_lineup,
    n_sims = n_sims,
    seed = seed
  )

  best_runs <- optimizer_result$top_lineups$expected_runs[1]

  comparison <- tibble(
    lineup_type = c("Custom lineup", "Model best lineup"),
    expected_runs = c(custom_score$mean_runs, best_runs),
    difference_from_model = c(custom_score$mean_runs - best_runs, 0)
  )

  side_by_side <- tibble(
    batting_order = 1:9,
    custom_player = custom_lineup$player,
    model_player = optimizer_result$best_lineup$player
  )

  list(
    custom_lineup = custom_lineup,
    comparison = comparison,
    side_by_side = side_by_side
  )
}

summarize_top_lineups <- function(optimizer_result, top_n = 20) {
  top_lineups <- optimizer_result$top_lineups %>%
    slice_head(n = top_n) %>%
    mutate(lineup_rank = row_number())

  parsed <- top_lineups %>%
    select(lineup_rank, expected_runs, lineup) %>%
    separate_rows(lineup, sep = " \\| ") %>%
    mutate(
      batting_order = as.integer(str_extract(lineup, "^\\d+")),
      player = str_squish(str_remove(lineup, "^\\d+\\.\\s*"))
    )

  player_summary <- parsed %>%
    group_by(player) %>%
    summarize(
      times_in_top_lineups = n(),
      average_order_spot = mean(batting_order),
      most_common_spot = as.integer(names(sort(table(batting_order), decreasing = TRUE))[1]),
      .groups = "drop"
    ) %>%
    arrange(desc(times_in_top_lineups), average_order_spot)

  slot_summary <- parsed %>%
    count(batting_order, player, name = "times_in_spot") %>%
    group_by(batting_order) %>%
    mutate(spot_share = times_in_spot / sum(times_in_spot)) %>%
    arrange(batting_order, desc(spot_share)) %>%
    slice_head(n = 3) %>%
    ungroup()

  list(
    player_summary = player_summary,
    slot_summary = slot_summary
  )
}
