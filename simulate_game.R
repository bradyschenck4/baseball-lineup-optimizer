library(dplyr)
library(tibble)

plate_appearance <- function(hitter) {
  events <- c("BB", "HBP", "1B", "2B", "3B", "HR", "Out")

  probs <- c(
    hitter$p_bb,
    hitter$p_hbp,
    hitter$p_1b,
    hitter$p_2b,
    hitter$p_3b,
    hitter$p_hr,
    hitter$p_out
  )

  probs[is.na(probs)] <- 0

  if (sum(probs) <= 0) {
    probs <- c(0, 0, 0, 0, 0, 0, 1)
  }

  sample(events, size = 1, prob = probs / sum(probs))
}

advance_runners <- function(event, base_state, outs) {
  b1 <- base_state[1]
  b2 <- base_state[2]
  b3 <- base_state[3]
  runs <- 0

  if (event == "Out") {
    return(list(bases = base_state, outs = outs + 1, runs = 0))
  }

  if (event %in% c("BB", "HBP")) {
    runs <- ifelse(b1 == 1 && b2 == 1 && b3 == 1, 1, 0)
    b3_new <- ifelse(b1 == 1 && b2 == 1, 1, b3)
    b2_new <- ifelse(b1 == 1, 1, b2)
    b1_new <- 1

    return(list(
      bases = c(b1_new, b2_new, b3_new),
      outs = outs,
      runs = runs
    ))
  }

  if (event == "1B") {
    return(list(
      bases = c(1, b1, b2),
      outs = outs,
      runs = b3
    ))
  }

  if (event == "2B") {
    return(list(
      bases = c(0, 1, b1),
      outs = outs,
      runs = b2 + b3
    ))
  }

  if (event == "3B") {
    return(list(
      bases = c(0, 0, 1),
      outs = outs,
      runs = b1 + b2 + b3
    ))
  }

  if (event == "HR") {
    return(list(
      bases = c(0, 0, 0),
      outs = outs,
      runs = b1 + b2 + b3 + 1
    ))
  }

  stop("Unknown event: ", event)
}

simulate_game <- function(lineup, innings = 9, max_pa = 120) {
  stopifnot(nrow(lineup) == 9)
  stopifnot(!anyDuplicated(lineup$player))

  runs <- 0
  batter_index <- 1
  pa_count <- 0

  for (inning in seq_len(innings)) {
    outs <- 0
    bases <- c(0, 0, 0)

    while (outs < 3) {
      pa_count <- pa_count + 1

      if (pa_count > max_pa) {
        stop("Simulation exceeded max_pa. Check event probabilities.")
      }

      hitter <- lineup[batter_index, ]
      event <- plate_appearance(hitter)
      new_state <- advance_runners(event, bases, outs)

      bases <- new_state$bases
      outs <- new_state$outs
      runs <- runs + new_state$runs

      batter_index <- batter_index + 1
      if (batter_index > nrow(lineup)) {
        batter_index <- 1
      }
    }
  }

  runs
}

simulate_lineup <- function(lineup, n_sims = 1000, seed = NULL) {
  if (!is.null(seed)) {
    set.seed(seed)
  }

  sim_runs <- replicate(n_sims, simulate_game(lineup))

  tibble(
    mean_runs = mean(sim_runs),
    median_runs = median(sim_runs),
    sd_runs = sd(sim_runs),
    p10_runs = as.numeric(quantile(sim_runs, 0.10)),
    p90_runs = as.numeric(quantile(sim_runs, 0.90)),
    n_sims = n_sims
  )
}
