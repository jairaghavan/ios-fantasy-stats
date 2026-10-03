"""
Pulls NFL player weekly stats, rosters, and schedules from nflverse 
https://github.com/nflverse/nflverse-data/releases,
reads directly from the release parquet files,
and writes them into a SQLite database matching the Flutter app's schema
(players / games / player_game_stats).

Setup:
    pip install nfl_data_py
    pip install pandas numpy pyarrow appdirs fastparquet requests

    (If pip complains about building pandas from source, it's because
    nfl_data_py pins pandas<2.0, which has no prebuilt wheel for Python 3.12+.
    Install nfl_data_py with --no-deps first, then install modern pandas/numpy
    separately -- it works fine despite the pin.)

Usage:
    python build_fantasy_db.py --start-year 2022 --end-year 2025
"""

import argparse
import os
import sqlite3
from datetime import datetime, timezone
import pandas as pd
import nfl_data_py as nfl


def current_season_year():
    """
    NFL seasons are labeled by the year they start in (e.g. games played in
    Jan/Feb 2027 belong to the "2026 season"). This lets --end-year default
    to "whatever season is currently relevant" so scheduled runs never need
    a manual yearly bump.
    """
    now = datetime.now(timezone.utc)
    return now.year - 1 if now.month <= 2 else now.year

STATS_URL_TEMPLATE = (
    "https://github.com/nflverse/nflverse-data/releases/download/"
    "stats_player/stats_player_week_{year}.parquet"
)

# Only skill positions with meaningful raw stat columns in this schema.
# Kickers (K) are intentionally excluded: nflverse precomputes their fantasy
# points correctly, but this schema has no field-goal/extra-point columns,
# so their game log would show all zeros. Add FG/XP columns first if you
# want to bring kickers in.
ALLOWED_POSITIONS = ("QB", "RB", "WR", "TE")

SCHEMA = """
CREATE TABLE IF NOT EXISTS players (
    player_id     TEXT PRIMARY KEY,
    full_name     TEXT NOT NULL,
    position      TEXT NOT NULL,
    team          TEXT,
    status        TEXT
);

CREATE TABLE IF NOT EXISTS games (
    game_id       TEXT PRIMARY KEY,
    season        INTEGER NOT NULL,
    week          INTEGER NOT NULL,
    game_date     TEXT,
    home_team     TEXT,
    away_team     TEXT
);

CREATE TABLE IF NOT EXISTS player_game_stats (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
    player_id             TEXT NOT NULL REFERENCES players(player_id),
    game_id               TEXT,
    season                INTEGER NOT NULL,
    week                  INTEGER NOT NULL,
    pass_att              INTEGER DEFAULT 0,
    pass_cmp              INTEGER DEFAULT 0,
    pass_yards            INTEGER DEFAULT 0,
    pass_td               INTEGER DEFAULT 0,
    interceptions         INTEGER DEFAULT 0,
    rush_att              INTEGER DEFAULT 0,
    rush_yards            INTEGER DEFAULT 0,
    rush_td               INTEGER DEFAULT 0,
    targets               INTEGER DEFAULT 0,
    receptions            INTEGER DEFAULT 0,
    rec_yards             INTEGER DEFAULT 0,
    rec_td                INTEGER DEFAULT 0,
    fumbles_lost          INTEGER DEFAULT 0,
    two_pt_conversions    INTEGER DEFAULT 0,
    fantasy_pts_std       REAL DEFAULT 0,
    fantasy_pts_half_ppr  REAL DEFAULT 0,
    fantasy_pts_ppr       REAL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_players_name ON players(full_name);
CREATE INDEX IF NOT EXISTS idx_stats_player ON player_game_stats(player_id, season, week);
"""


def build_players_table(conn, years):
    print("Fetching roster/player info...")
    rosters = nfl.import_seasonal_rosters(years)

    rosters = rosters[rosters["position"].isin(ALLOWED_POSITIONS)]

    # Keep the most recent season's row per player as the "current" snapshot
    rosters = rosters.sort_values("season").drop_duplicates("player_id", keep="last")

    players = rosters[["player_id", "player_name", "position", "team", "status"]].copy()
    players.columns = ["player_id", "full_name", "position", "team", "status"]
    players = players.dropna(subset=["player_id", "full_name"])

    players.to_sql("players", conn, if_exists="append", index=False)
    print(f"  Inserted {len(players)} players.")


def build_games_table(conn, years):
    print("Fetching schedules...")
    schedules = nfl.import_schedules(years)

    games = schedules[["game_id", "season", "week", "gameday", "home_team", "away_team"]].copy()
    games.columns = ["game_id", "season", "week", "game_date", "home_team", "away_team"]
    games = games.dropna(subset=["game_id"])

    games.to_sql("games", conn, if_exists="append", index=False)
    print(f"  Inserted {len(games)} games.")


def build_stats_table(conn, years):
    print("Fetching weekly player stats...")

    frames = []
    for year in years:
        url = STATS_URL_TEMPLATE.format(year=year)
        print(f"  Downloading {url}")
        frames.append(pd.read_parquet(url))
    weekly = pd.concat(frames, ignore_index=True)

    # A handful of rows per team/week are team-level placeholders (no
    # individual player attribution -- e.g. aggregate defense/special-teams
    # rows) and have a null player_id. Drop them rather than let fillna()
    # coerce them into a fake "0" player_id later.
    before = len(weekly)
    weekly = weekly.dropna(subset=["player_id"])
    dropped = before - len(weekly)
    if dropped:
        print(f"  Dropped {dropped} team-level placeholder rows with no player_id.")

    before = len(weekly)
    weekly = weekly[weekly["position"].isin(ALLOWED_POSITIONS)]
    print(f"  Dropped {before - len(weekly)} rows for non-fantasy-relevant positions.")

    def col(name):
        return weekly[name] if name in weekly.columns else 0

    stats = pd.DataFrame({
        "player_id": weekly["player_id"],
        "game_id": col("game_id"),
        "season": weekly["season"],
        "week": weekly["week"],
        "pass_att": col("attempts"),
        "pass_cmp": col("completions"),
        "pass_yards": col("passing_yards"),
        "pass_td": col("passing_tds"),
        "interceptions": col("passing_interceptions"),
        "rush_att": col("carries"),
        "rush_yards": col("rushing_yards"),
        "rush_td": col("rushing_tds"),
        "targets": col("targets"),
        "receptions": col("receptions"),
        "rec_yards": col("receiving_yards"),
        "rec_td": col("receiving_tds"),
        "fumbles_lost": col("fumbles_lost_total"),
        "two_pt_conversions": (
            col("passing_2pt_conversions")
            + col("rushing_2pt_conversions")
            + col("receiving_2pt_conversions")
        ),
        "fantasy_pts_std": weekly["fantasy_points"],
        "fantasy_pts_ppr": weekly["fantasy_points_ppr"],
    })

    # Half-PPR: standard points plus 0.5 per reception (PPR adds a full 1.0)
    stats["fantasy_pts_half_ppr"] = stats["fantasy_pts_std"] + 0.5 * stats["receptions"]

    # Only fill numeric stat columns with 0 -- never touch player_id/game_id,
    # since a filled-in fake ID is worse than a missing one.
    numeric_cols = [c for c in stats.columns if c not in ("player_id", "game_id")]
    stats[numeric_cols] = stats[numeric_cols].fillna(0)

    stats.to_sql("player_game_stats", conn, if_exists="append", index=False)
    print(f"  Inserted {len(stats)} game-stat rows.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--start-year", type=int, default=2022)
    parser.add_argument("--end-year", type=int, default=current_season_year())
    parser.add_argument("--out", default="assets/db/fantasy_stats.db")
    args = parser.parse_args()

    years = list(range(args.start_year, args.end_year + 1))
    out_dir = os.path.dirname(args.out)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)

    if os.path.exists(args.out):
        os.remove(args.out)  # rebuild fresh each run

    conn = sqlite3.connect(args.out)
    conn.executescript(SCHEMA)

    build_players_table(conn, years)
    build_games_table(conn, years)
    build_stats_table(conn, years)

    conn.commit()
    conn.close()
    print(f"\nDone. Database written to {args.out}")


if __name__ == "__main__":
    main()
