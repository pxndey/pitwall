"""F1 Data Service — wraps FastF1's Ergast interface to provide structured F1 data."""

from __future__ import annotations

import logging
import time
from datetime import datetime, timezone

from fastf1.ergast import Ergast

logger = logging.getLogger(__name__)

# Cache TTLs (seconds)
_TTL_STANDINGS = 300   # standings / schedule refresh every 5 min
_TTL_RESULTS = 3600    # historical results refresh every hour


class F1DataService:
    """Provides F1 data via FastF1's Ergast API with simple TTL-based caching."""

    def __init__(self) -> None:
        self._ergast = Ergast()
        self._cache: dict[str, tuple[object, float]] = {}

    # ------------------------------------------------------------------
    # Caching helper
    # ------------------------------------------------------------------

    def _cached(self, key: str, ttl: int, fetch_fn):
        """Return cached value if fresh, otherwise call *fetch_fn* and cache."""
        now = time.time()
        if key in self._cache:
            val, ts = self._cache[key]
            if now - ts < ttl:
                return val
        val = fetch_fn()
        self._cache[key] = (val, now)
        return val

    # ------------------------------------------------------------------
    # Public methods
    # ------------------------------------------------------------------

    def get_driver_standings(self, season: int = 2025) -> list[dict]:
        """Current driver championship standings."""

        def _fetch():
            try:
                standings = self._ergast.get_driver_standings(season=season)
                df = standings.content[0]
                return df.to_dict(orient="records")
            except Exception as exc:
                logger.error("Failed to fetch driver standings: %s", exc)
                return []

        return self._cached(f"driver_standings_{season}", _TTL_STANDINGS, _fetch)

    def get_constructor_standings(self, season: int = 2025) -> list[dict]:
        """Current constructor championship standings."""

        def _fetch():
            try:
                standings = self._ergast.get_constructor_standings(season=season)
                df = standings.content[0]
                return df.to_dict(orient="records")
            except Exception as exc:
                logger.error("Failed to fetch constructor standings: %s", exc)
                return []

        return self._cached(f"constructor_standings_{season}", _TTL_STANDINGS, _fetch)

    def get_race_results(self, season: int, round_num: int) -> dict:
        """Results for a specific race.

        Returns ``{race_info: {season, round}, results: [...]}``.
        """

        def _fetch():
            try:
                results = self._ergast.get_race_results(season=season, round=round_num)
                df = results.content[0]
                return {
                    "race_info": {"season": season, "round": round_num},
                    "results": df.to_dict(orient="records"),
                }
            except Exception as exc:
                logger.error("Failed to fetch race results (s=%s r=%s): %s", season, round_num, exc)
                return {"race_info": {"season": season, "round": round_num}, "results": []}

        return self._cached(f"race_results_{season}_{round_num}", _TTL_RESULTS, _fetch)

    def get_qualifying_results(self, season: int, round_num: int) -> dict:
        """Qualifying results for a specific round.

        Returns ``{race_info: {season, round}, qualifying: [...]}``.
        """

        def _fetch():
            try:
                quali = self._ergast.get_qualifying_results(season=season, round=round_num)
                df = quali.content[0]
                return {
                    "race_info": {"season": season, "round": round_num},
                    "qualifying": df.to_dict(orient="records"),
                }
            except Exception as exc:
                logger.error("Failed to fetch qualifying results (s=%s r=%s): %s", season, round_num, exc)
                return {"race_info": {"season": season, "round": round_num}, "qualifying": []}

        return self._cached(f"qualifying_{season}_{round_num}", _TTL_RESULTS, _fetch)

    def get_lap_times(self, season: int, round_num: int) -> list[dict]:
        """Lap-by-lap timing data for a race."""

        def _fetch():
            try:
                laps = self._ergast.get_lap_times(season=season, round=round_num)
                df = laps.content[0]
                return df.to_dict(orient="records")
            except Exception as exc:
                logger.error(
                    "Failed to fetch lap times (s=%s r=%s): %s",
                    season, round_num, exc,
                )
                return []

        return self._cached(f"laps_{season}_{round_num}", _TTL_RESULTS, _fetch)

    def get_race_schedule(self, season: int = 2025) -> list[dict]:
        """Full season calendar."""

        def _fetch():
            try:
                schedule = self._ergast.get_race_schedule(season=season)
                # get_race_schedule returns a DataFrame directly
                return schedule.to_dict(orient="records")
            except Exception as exc:
                logger.error("Failed to fetch race schedule: %s", exc)
                return []

        return self._cached(f"schedule_{season}", _TTL_STANDINGS, _fetch)

    def get_drivers(self, season: int = 2025) -> list[dict]:
        """All drivers for a season."""

        def _fetch():
            try:
                drivers = self._ergast.get_driver_info(season=season, limit=100)
                return drivers.to_dict(orient="records")
            except Exception as exc:
                logger.error("Failed to fetch drivers: %s", exc)
                return []

        return self._cached(f"drivers_{season}", _TTL_STANDINGS, _fetch)

    def get_constructors(self, season: int = 2025) -> list[dict]:
        """All constructors for a season."""

        def _fetch():
            try:
                constructors = self._ergast.get_constructor_info(season=season, limit=100)
                return constructors.to_dict(orient="records")
            except Exception as exc:
                logger.error("Failed to fetch constructors: %s", exc)
                return []

        return self._cached(f"constructors_{season}", _TTL_STANDINGS, _fetch)

    def get_next_race(self) -> dict | None:
        """Find the next upcoming race from the schedule."""
        try:
            schedule = self.get_race_schedule()
            now = datetime.now(tz=timezone.utc)
            for race in schedule:
                # Ergast schedule rows contain a 'raceDate' or 'date' field
                race_date_str = race.get("raceDate") or race.get("date", "")
                if not race_date_str:
                    continue
                try:
                    race_date = datetime.fromisoformat(str(race_date_str)).replace(tzinfo=timezone.utc)
                except (ValueError, TypeError):
                    continue
                if race_date >= now:
                    return race
            return None
        except Exception as exc:
            logger.error("Failed to find next race: %s", exc)
            return None

    def get_driver_season_results(self, driver_id: str, season: int = 2025) -> list[dict]:
        """All race results for a specific driver in a season."""
        try:
            schedule = self.get_race_schedule(season)
            driver_results = []
            for race in schedule:
                round_num = race.get("round")
                if round_num is None:
                    continue
                race_data = self.get_race_results(season, int(round_num))
                results = race_data.get("results", [])
                for entry in results:
                    entry_driver = (
                        entry.get("driverId", "")
                        or entry.get("driverCode", "")
                        or ""
                    )
                    if entry_driver.lower() == driver_id.lower():
                        entry["race_round"] = round_num
                        entry["race_name"] = race.get("raceName", "")
                        driver_results.append(entry)
                        break
                # If we hit a race with no results, we've reached unraced rounds
                if not results:
                    break
            return driver_results
        except Exception as exc:
            logger.error("Failed to fetch driver season results: %s", exc)
            return []

    def get_h2h_drivers(self, driver1_id: str, driver2_id: str, season: int = 2025) -> dict:
        """Head-to-head comparison data for two drivers across a season.

        Returns::

            {
                driver1: {name, points, wins, podiums, avg_position, race_results: [...]},
                driver2: {same structure},
                qualifying_h2h: {driver1_ahead: N, driver2_ahead: N},
            }
        """
        d1_id = driver1_id.lower()
        d2_id = driver2_id.lower()

        # Pre-populate name/code from drivers list
        drivers = self.get_drivers(season)
        def _driver_meta(did: str) -> dict:
            for d in drivers:
                if d.get("driverId", "").lower() == did:
                    code = d.get("driverCode") or d.get("code") or did.upper()[:3]
                    name = f"{d.get('givenName','')} {d.get('familyName','')}".strip()
                    return {"name": name, "code": code}
            return {"name": did, "code": did.upper()[:3]}

        summary: dict = {
            "driver1": {
                "id": driver1_id, "points": 0, "wins": 0, "podiums": 0,
                "dnfs": 0, "positions": [], "race_results": [],
                **_driver_meta(d1_id),
            },
            "driver2": {
                "id": driver2_id, "points": 0, "wins": 0, "podiums": 0,
                "dnfs": 0, "positions": [], "race_results": [],
                **_driver_meta(d2_id),
            },
            "qualifying_h2h": {"driver1_ahead": 0, "driver2_ahead": 0},
            "race_h2h": {"driver1_ahead": 0, "driver2_ahead": 0},
        }

        try:
            schedule = self.get_race_schedule(season)

            for race in schedule:
                round_num = race.get("round")
                if round_num is None:
                    continue
                rnd = int(round_num)

                # --- Race results ---
                race_data = self.get_race_results(season, rnd)
                results = race_data.get("results", [])
                if not results:
                    break  # no more completed races

                d1_entry, d2_entry = None, None
                for entry in results:
                    eid = (entry.get("driverId", "") or entry.get("driverCode", "") or "").lower()
                    if eid == d1_id:
                        d1_entry = entry
                    elif eid == d2_id:
                        d2_entry = entry

                for label, entry in [("driver1", d1_entry), ("driver2", d2_entry)]:
                    if entry is None:
                        continue
                    pts = float(entry.get("points", 0))
                    pos = entry.get("position") or entry.get("positionOrder")
                    status = str(entry.get("status", ""))
                    try:
                        pos = int(pos)
                    except (TypeError, ValueError):
                        pos = None

                    summary[label]["points"] += pts
                    if pos == 1:
                        summary[label]["wins"] += 1
                    if pos is not None and pos <= 3:
                        summary[label]["podiums"] += 1
                    if pos is not None:
                        summary[label]["positions"].append(pos)
                    if status and status not in ("Finished", "+1 Lap", "+2 Laps", "+3 Laps"):
                        summary[label]["dnfs"] += 1
                    summary[label]["race_results"].append({
                        "round": rnd,
                        "race": race.get("raceName", ""),
                        "position": pos,
                        "grid": entry.get("grid"),
                        "points": pts,
                        "status": status,
                    })

                # Race head-to-head
                if d1_entry and d2_entry:
                    p1 = d1_entry.get("position") or d1_entry.get("positionOrder")
                    p2 = d2_entry.get("position") or d2_entry.get("positionOrder")
                    try:
                        p1, p2 = int(p1), int(p2)
                        if p1 < p2:
                            summary["race_h2h"]["driver1_ahead"] += 1
                        elif p2 < p1:
                            summary["race_h2h"]["driver2_ahead"] += 1
                    except (TypeError, ValueError):
                        pass

                # --- Qualifying ---
                quali_data = self.get_qualifying_results(season, rnd)
                quali = quali_data.get("qualifying", [])
                d1_qpos, d2_qpos = None, None
                for qe in quali:
                    qid = (qe.get("driverId", "") or qe.get("driverCode", "") or "").lower()
                    pos = qe.get("position")
                    try:
                        pos = int(pos)
                    except (TypeError, ValueError):
                        pos = None
                    if qid == d1_id:
                        d1_qpos = pos
                    elif qid == d2_id:
                        d2_qpos = pos

                if d1_qpos is not None and d2_qpos is not None:
                    if d1_qpos < d2_qpos:
                        summary["qualifying_h2h"]["driver1_ahead"] += 1
                    elif d2_qpos < d1_qpos:
                        summary["qualifying_h2h"]["driver2_ahead"] += 1

            # Compute average positions
            for label in ("driver1", "driver2"):
                positions = summary[label].pop("positions")
                if positions:
                    summary[label]["avg_position"] = round(sum(positions) / len(positions), 2)
                else:
                    summary[label]["avg_position"] = None

        except Exception as exc:
            logger.error("Failed to build H2H driver comparison: %s", exc)

        return summary

    def get_h2h_constructors(self, team1_id: str, team2_id: str, season: int = 2025) -> dict:
        """Head-to-head comparison data for two constructors across a season.

        Returns::

            {
                team1: {id, points, wins, podiums, best_finish_per_race: [...],
                        dnfs: N, positions: []},
                team2: {same structure},
                qualifying_h2h: {team1_ahead: N, team2_ahead: N, by_round: {...}},
                race_h2h: {team1_ahead: N, team2_ahead: N, by_round: {...}},
            }

        qualifying_h2h and race_h2h track which constructor's best-placed driver
        out-qualified / out-finished the other, mirroring the per-race structure
        of get_h2h_drivers.
        """
        t1_id = team1_id.lower()
        t2_id = team2_id.lower()

        summary: dict = {
            "team1": {
                "id": team1_id, "points": 0, "wins": 0, "podiums": 0,
                "dnfs": 0, "positions": [], "best_finish_per_race": [],
            },
            "team2": {
                "id": team2_id, "points": 0, "wins": 0, "podiums": 0,
                "dnfs": 0, "positions": [], "best_finish_per_race": [],
            },
            "qualifying_h2h": {"team1_ahead": 0, "team2_ahead": 0, "by_round": {}},
            "race_h2h": {"team1_ahead": 0, "team2_ahead": 0, "by_round": {}},
        }

        try:
            schedule = self.get_race_schedule(season)

            for race in schedule:
                round_num = race.get("round")
                if round_num is None:
                    continue
                rnd = int(round_num)
                race_name = race.get("raceName", "")

                # --- Race results ---
                race_data = self.get_race_results(season, rnd)
                results = race_data.get("results", [])
                if not results:
                    break

                t1_best_pos: int | None = None
                t2_best_pos: int | None = None

                for label, tid in [("team1", t1_id), ("team2", t2_id)]:
                    team_entries = []
                    for entry in results:
                        ctor = (
                            entry.get("constructorId", "")
                            or entry.get("constructorName", "")
                            or ""
                        ).lower()
                        if ctor == tid:
                            team_entries.append(entry)

                    race_points = 0.0
                    best_pos: int | None = None
                    for te in team_entries:
                        pts = float(te.get("points", 0))
                        race_points += pts
                        pos = te.get("position") or te.get("positionOrder")
                        try:
                            pos = int(pos)
                        except (TypeError, ValueError):
                            pos = None
                        if pos is not None:
                            if best_pos is None or pos < best_pos:
                                best_pos = pos
                        status = str(te.get("status", ""))
                        if status and status not in ("Finished", "+1 Lap", "+2 Laps", "+3 Laps"):
                            summary[label]["dnfs"] += 1

                    summary[label]["points"] += race_points
                    if best_pos == 1:
                        summary[label]["wins"] += 1
                    if best_pos is not None and best_pos <= 3:
                        summary[label]["podiums"] += 1
                    if best_pos is not None:
                        summary[label]["positions"].append(best_pos)
                    summary[label]["best_finish_per_race"].append({
                        "round": rnd,
                        "race_name": race_name,
                        "best_position": best_pos,
                        "points": race_points,
                    })

                    if label == "team1":
                        t1_best_pos = best_pos
                    else:
                        t2_best_pos = best_pos

                # Race head-to-head (lower position number = better finish)
                if t1_best_pos is not None and t2_best_pos is not None:
                    if t1_best_pos < t2_best_pos:
                        summary["race_h2h"]["team1_ahead"] += 1
                        summary["race_h2h"]["by_round"][rnd] = {
                            "race_name": race_name, "winner": "team1",
                            "team1_pos": t1_best_pos, "team2_pos": t2_best_pos,
                        }
                    elif t2_best_pos < t1_best_pos:
                        summary["race_h2h"]["team2_ahead"] += 1
                        summary["race_h2h"]["by_round"][rnd] = {
                            "race_name": race_name, "winner": "team2",
                            "team1_pos": t1_best_pos, "team2_pos": t2_best_pos,
                        }

                # --- Qualifying ---
                quali_data = self.get_qualifying_results(season, rnd)
                quali = quali_data.get("qualifying", [])
                t1_best_qpos: int | None = None
                t2_best_qpos: int | None = None
                for qe in quali:
                    ctor = (
                        qe.get("constructorId", "")
                        or qe.get("constructorName", "")
                        or ""
                    ).lower()
                    qpos = qe.get("position")
                    try:
                        qpos = int(qpos)
                    except (TypeError, ValueError):
                        qpos = None
                    if ctor == t1_id:
                        if qpos is not None and (t1_best_qpos is None or qpos < t1_best_qpos):
                            t1_best_qpos = qpos
                    elif ctor == t2_id:
                        if qpos is not None and (t2_best_qpos is None or qpos < t2_best_qpos):
                            t2_best_qpos = qpos

                if t1_best_qpos is not None and t2_best_qpos is not None:
                    if t1_best_qpos < t2_best_qpos:
                        summary["qualifying_h2h"]["team1_ahead"] += 1
                        summary["qualifying_h2h"]["by_round"][rnd] = {
                            "race_name": race_name, "winner": "team1",
                            "team1_pos": t1_best_qpos, "team2_pos": t2_best_qpos,
                        }
                    elif t2_best_qpos < t1_best_qpos:
                        summary["qualifying_h2h"]["team2_ahead"] += 1
                        summary["qualifying_h2h"]["by_round"][rnd] = {
                            "race_name": race_name, "winner": "team2",
                            "team1_pos": t1_best_qpos, "team2_pos": t2_best_qpos,
                        }

            # Compute average best-finish positions per constructor
            for label in ("team1", "team2"):
                positions = summary[label].pop("positions")
                if positions:
                    summary[label]["avg_best_position"] = round(
                        sum(positions) / len(positions), 2
                    )
                else:
                    summary[label]["avg_best_position"] = None

        except Exception as exc:
            logger.error("Failed to build H2H constructor comparison: %s", exc)

        return summary
