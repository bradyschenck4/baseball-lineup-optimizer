library(dplyr)
library(purrr)
library(tibble)

slot_weights <- c(1.12, 1.10, 1.08, 1.06, 1.02, 0.99, 0.96, 0.94, 0.92)

quick_lineup_score <- function(lineup) {
  sum(
    slot_weights * (
      0.50 * lineup$run_value +
        0.30 * lineup$obp +
        0.20 * lineup$slg_proxy
    ),
    na.rm = TRUE
  )
}

make_random_orders <- function(players, lineup_size, n_candidates, seed = 123) {
  set.seed(seed)

  replicate(
    n_candidates,
    sample(players, size = lineup_size, replace = FALSE),
    simplify = FALSE
  )
}

make_heuristic_orders <- function(profiles, lineup_size = 9) {
  best_obp <- profiles %>%
    arrange(desc(obp)) %>%
    slice_head(n = lineup_size) %>%
    pull(player)

  best_power <- profiles %>%
    arrange(desc(slg_proxy)) %>%
    slice_head(n = lineup_size) %>%
    pull(player)

  best_run_value <- profiles %>%
    arrange(desc(run_value)) %>%
    slice_head(n = lineup_size) %>%
    pull(player)

  list(best_obp, best_power, best_run_value)
}

dedupe_orders <- function(candidate_orders) {
  order_keys <- vapply(candidate_orders, paste, collapse = " | ", FUN.VALUE = character(1))
  candidate_orders[!duplicated(order_keys)]
}

screen_lineups <- function(profiles, candidate_orders, keep = 75) {
  screened <- map_dfr(seq_along(candidate_orders), function(i) {
    order <- candidate_orders[[i]]

    lineup <- profiles %>%
      slice(match(order, player))

    tibble(
      candidate_id = i,
      quick_score = quick_lineup_score(lineup),
      lineup = paste0(seq_along(order), ". ", order, collapse = " | ")
    )
  })

  screened %>%
    arrange(desc(quick_score)) %>%
    slice_head(n = keep)
}

lineup_string_to_players <- function(lineup_string) {
  lineup_string %>%
    stringr::str_remove_all("\\d+\\.\\s*") %>%
    stringr::str_split(" \\| ") %>%
    unlist()
}

optimize_lineup <- function(profiles,
                            roster = NULL,
                            lineup_size = 9,
                            n_candidates = 5000,
                            pre_screen_n = 75,
                            n_sims = 500,
                            seed = 123) {
  set.seed(seed)

  player_pool <- profiles

  if (!is.null(roster)) {
    player_pool <- profiles %>%
      filter(player %in% roster)

    missing_players <- setdiff(roster, player_pool$player)

    if (length(missing_players) > 0) {
      warning("Could not match: ", paste(missing_players, collapse = ", "))
    }
  }

  if (nrow(player_pool) < lineup_size) {
    stop("Need at least ", lineup_size, " hitters. Found ", nrow(player_pool), ".")
  }

  random_orders <- make_random_orders(
    players = player_pool$player,
    lineup_size = lineup_size,
    n_candidates = n_candidates,
    seed = seed
  )

  heuristic_orders <- make_heuristic_orders(player_pool, lineup_size)
  candidate_orders <- dedupe_orders(c(heuristic_orders, random_orders))

  quick_screen <- screen_lineups(
    profiles = player_pool,
    candidate_orders = candidate_orders,
    keep = pre_screen_n
  )

  sim_results <- map_dfr(seq_len(nrow(quick_screen)), function(i) {
    order <- lineup_string_to_players(quick_screen$lineup[i])

    lineup <- player_pool %>%
      slice(match(order, player))

    sim <- simulate_lineup(
      lineup = lineup,
      n_sims = n_sims,
      seed = seed + i
    )

    tibble(
      candidate_id = quick_screen$candidate_id[i],
      expected_runs = sim$mean_runs,
      median_runs = sim$median_runs,
      sd_runs = sim$sd_runs,
      quick_score = quick_screen$quick_score[i],
      lineup = quick_screen$lineup[i]
    )
  }) %>%
    arrange(desc(expected_runs))

  best_players <- lineup_string_to_players(sim_results$lineup[1])

  best_lineup <- player_pool %>%
    slice(match(best_players, player)) %>%
    mutate(batting_order = row_number()) %>%
    select(
      batting_order,
      player,
      bats,
      pa,
      obp,
      slg_proxy,
      run_value,
      p_bb,
      p_hbp,
      p_1b,
      p_2b,
      p_3b,
      p_hr,
      p_out
    )

  list(
    best_lineup = best_lineup,
    top_lineups = sim_results,
    quick_screen = quick_screen,
    player_pool = player_pool,
    settings = list(
      n_candidates = length(candidate_orders),
      pre_screen_n = pre_screen_n,
      n_sims = n_sims,
      seed = seed
    )
  )
}
