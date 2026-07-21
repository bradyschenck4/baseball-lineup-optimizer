# baseball-lineup-optimizer

**Baseball Lineup Optimizer**

This project builds a Monte Carlo simulation model for evaluating baseball batting orders using hitter event probabilities.

The goal is to estimate expected run production for different lineup combinations and provide a simple, explainable framework for comparing batting orders. The public version uses synthetic data and does not include any private team data, TrackMan files, player reports, or proprietary materials.

**Overview**

A batting order can change run production even when the same nine hitters are used. This project models each hitter by their probabilities of different plate appearance outcomes, then simulates full 9-inning games to estimate how many runs each lineup is expected to score.

The optimizer generates candidate batting orders, pre-screens them with a quick scoring method, and runs full Monte Carlo simulations on the most promising options.

**Features:**

- Builds hitter profiles from plate appearance outcome data
- Uses sample-size shrinkage to stabilize small-sample player rates
- Simulates full 9-inning games using hitter event probabilities
- Generates and evaluates thousands of candidate batting orders
- Ranks lineups by projected run production
- Compares a custom lineup against the model’s top recommendation
- Summarizes common players and batting-order spots across top lineups

## Repository Structure

```text
baseball-lineup-optimizer/
├── README.md
├── data/
│   └── sample_hitters.csv
├── R/
│   ├── build_profiles.R
│   ├── simulate_game.R
│   ├── optimize_lineup.R
│   └── reporting.R
├── analysis/
│   └── run_optimizer.R
└── outputs/
    ├── best_lineup.csv
    ├── top_lineups.csv
    └── custom_lineup_comparison.csv
```
    
**Data**

The sample dataset contains synthetic hitter outcome counts. Each row represents one hitter and includes plate appearance totals for:

- walks
- hit by pitch
- singles
- doubles
- triples
- home runs
- outs

The model converts these overall counts into event probabilities for each hitter.

**Methodology**

1. Build hitter profiles

Each hitter is assigned probabilities for seven possible plate appearance outcomes:

BB, HBP, 1B, 2B, 3B, HR, Out

Because small samples can create noisy player rates, the model shrinks each hitter’s raw event probabilities toward the team average. This keeps the optimizer from overreacting to limited plate appearance samples.

2. Simulate games

The simulator runs through a full 9 inning game using the selected batting order. For each plate appearance, the hitter’s outcome is randomly sampled from their event probabilities.

Runner advancement is intentionally simplified:

- singles move runners one base
- doubles move runners two bases
- triples clear the bases and place the hitter on third
- home runs score all runners and the batter
- walks and hit by pitch force runners when necessary

This keeps the model transparent and easy to explain to coaches.

3. Optimize lineups

The optimizer creates a large set of candidate lineups and uses a quick score to identify the most promising orders. It then runs full Monte Carlo simulations on the top candidates and ranks them by average runs scored.

This approach avoids spending unnecessary time simulating weaker lineup combinations while still exploring a wide range of possible batting orders.

**Example Usage**

Run the full example workflow from a fresh R session:

source("analysis/run_optimizer.R")

The script will:

- Load the sample hitter data
- Build hitter profiles
- Generate candidate lineups
- Simulate the strongest candidates
- Write results to the outputs/ folder

**Example Outputs**

The project creates several output files:

- outputs/best_lineup.csv
- outputs/top_lineups.csv
- outputs/custom_lineup_comparison.csv
- outputs/lineup_side_by_side.csv
- outputs/top_lineup_player_summary.csv
- outputs/top_lineup_slot_summary.csv

These outputs show the model’s recommended lineup, the highest-ranked alternatives, and a comparison between a custom lineup and the model’s top choice.

**Requirements**

This project uses R and the following packages:

- dplyr
- readr
- purrr
- stringr
- tibble
- tidyr

Install them with:

install.packages(c("dplyr", "readr", "purrr", "stringr", "tibble", "tidyr"))

**Limitations**

This is an explainable portfolio version of a lineup optimizer, not a full professional run expectancy model.

The current version does not account for:

- pitcher quality
- platoon splits
- stolen bases
- sacrifice bunts
- double plays
- park factors
- batted-ball-specific runner advancement
- leverage or late-game strategy

Future versions could improve the model by adding handedness adjustments, more detailed base-state transition probabilities, and opponent-specific pitcher inputs.

**Project Motivation**

This project was created to explore how simulation and statistical modeling can support baseball decision making. Coaches often build batting orders by prioritizing certain player qualities for specific spots in the lineup. This model allows the lineup to be considered holistically, rather than building the lineup one spot at a time. 

