library(dplyr)
library(readr)

source("R/build_profiles.R")
source("R/simulate_game.R")
source("R/optimize_lineup.R")
source("R/reporting.R")

hitter_counts <- read_hitter_counts("data/sample_hitters.csv")

hitter_profiles <- build_hitter_profiles(
  hitter_counts = hitter_counts,
  prior_pa = 25
)

today_roster <- c(
  "Alex Carter",
  "Mason Blake",
  "Evan Brooks",
  "Tyler Reed",
  "Noah Sullivan",
  "Caleb Turner",
  "Jack Miller",
  "Ryan Hayes",
  "Luke Bennett",
  "Owen Parker",
  "Cole Jenkins"
)

lineup_result <- optimize_lineup(
  profiles = hitter_profiles,
  roster = today_roster,
  lineup_size = 9,
  n_candidates = 5000,
  pre_screen_n = 75,
  n_sims = 500,
  seed = 24
)

best_lineup <- lineup_result$best_lineup
top_lineups <- lineup_result$top_lineups %>%
  slice_head(n = 10)

custom_order <- c(
  "Mason Blake",
  "Alex Carter",
  "Tyler Reed",
  "Noah Sullivan",
  "Evan Brooks",
  "Caleb Turner",
  "Jack Miller",
  "Ryan Hayes",
  "Luke Bennett"
)

custom_result <- score_custom_lineup(
  lineup = custom_order,
  optimizer_result = lineup_result,
  n_sims = 1000,
  seed = 99
)

consensus <- summarize_top_lineups(
  optimizer_result = lineup_result,
  top_n = 20
)

dir.create("outputs", showWarnings = FALSE)

write_csv(best_lineup, "outputs/best_lineup.csv")
write_csv(top_lineups, "outputs/top_lineups.csv")
write_csv(custom_result$comparison, "outputs/custom_lineup_comparison.csv")
write_csv(custom_result$side_by_side, "outputs/lineup_side_by_side.csv")
write_csv(consensus$player_summary, "outputs/top_lineup_player_summary.csv")
write_csv(consensus$slot_summary, "outputs/top_lineup_slot_summary.csv")

print(best_lineup)

cat(
  "\nBest projected runs:",
  round(lineup_result$top_lineups$expected_runs[1], 2),
  "\n"
)

print(custom_result$comparison)
