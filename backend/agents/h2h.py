"""Head-to-Head comparison agent for F1 driver and constructor matchups."""

from __future__ import annotations

import re

from agents.base import BaseAgent


class H2HAgent(BaseAgent):
    """Compares two F1 drivers or two constructors using season data."""

    # Common driver nickname / first-name aliases -> family name (lower).
    _DRIVER_ALIASES: dict[str, str] = {
        "max": "verstappen",
        "checo": "perez",
        "lando": "norris",
        "charles": "leclerc",
        "carlos": "sainz",
        "lewis": "hamilton",
        "george": "russell",
        "oscar": "piastri",
        "danny ric": "ricciardo",
        "yuki": "tsunoda",
        "valtteri": "bottas",
        "valterri": "bottas",
        "hulk": "hulkenberg",
        "nico h": "hulkenberg",
        "alex": "albon",
        "pierre": "gasly",
        "esteban": "ocon",
        "fernando": "alonso",
        "lance": "stroll",
        "kevin": "magnussen",
        "kmag": "magnussen",
        "zhou": "zhou",
        "logan": "sargeant",
        "ollie": "bearman",
        "oliver": "bearman",
        "jack": "doohan",
        "kimi": "antonelli",
        "andrea": "antonelli",
        "isack": "hadjar",
        "gabriel": "bortoleto",
        "liam": "lawson",
    }

    # Common constructor aliases -> constructorId (lower).
    _TEAM_ALIASES: dict[str, str] = {
        "rb": "red_bull",
        "redbull": "red_bull",
        "red bull": "red_bull",
        "red bull racing": "red_bull",
        "merc": "mercedes",
        "ferrari": "ferrari",
        "mcl": "mclaren",
        "mclaren": "mclaren",
        "alpine": "alpine",
        "aston": "aston_martin",
        "aston martin": "aston_martin",
        "am": "aston_martin",
        "haas": "haas",
        "williams": "williams",
        "alpha tauri": "alphatauri",
        "alphatauri": "alphatauri",
        "alfa": "alfa",
        "alfa romeo": "alfa",
        "sauber": "sauber",
        "kick sauber": "sauber",
        "racing bulls": "rb",
        "visa rb": "rb",
        "vcarb": "rb",
    }

    # Separators used to split two entities from a comparison query.
    _SPLIT_PATTERNS = re.compile(
        r"\bvs\.?\b|\bversus\b|\bv\b|\bagainst\b|\band\b|\bor\b"
        r"|\bcompared\s+to\b|\bcompared\s+with\b|\bhead\s*to\s*head\b|\bh2h\b",
        re.IGNORECASE,
    )

    # Prefix phrases the user might use before naming the entities.
    _PREFIX_PATTERNS = re.compile(
        r"^(compare|match\s*up|h2h|head\s*to\s*head|who\s+is\s+better)\s+",
        re.IGNORECASE,
    )

    # Season year pattern (2000-2029).
    _SEASON_PATTERN = re.compile(r"\b(20[0-2]\d)\b")

    # ------------------------------------------------------------------ #
    #  BaseAgent interface                                                 #
    # ------------------------------------------------------------------ #

    def can_handle(self, message: str, intent: str) -> bool:
        return intent == "h2h"

    def handle(self, message: str, history: list, user_context: dict) -> str:
        fav_driver: str = user_context.get("fav_driver", "")
        fav_team: str = user_context.get("fav_team", "")
        season = self._extract_season(message)

        # Try driver comparison first, then constructor comparison.
        result = self._try_driver_comparison(message, season, fav_driver)
        if result is not None:
            _ctype, data = result
            formatted = self._format_driver_h2h(data, season)
            return self._generate_response(
                formatted, history, message, fav_driver, fav_team
            )

        result = self._try_constructor_comparison(message, season, fav_team)
        if result is not None:
            _ctype, data = result
            formatted = self._format_constructor_h2h(data, season)
            return self._generate_response(
                formatted, history, message, fav_driver, fav_team
            )

        # Could not determine entities.
        return (
            "I'd love to do a head-to-head comparison, but I need two drivers "
            "or two teams to compare. Try something like "
            "**Verstappen vs Norris** or **Red Bull vs McLaren**."
        )

    # ------------------------------------------------------------------ #
    #  Comparison attempts                                                 #
    # ------------------------------------------------------------------ #

    def _try_driver_comparison(
        self, message: str, season: int, fav_driver: str
    ) -> tuple[str, dict] | None:
        drivers = self.data.get_drivers(season=season)
        parts = self._split_entities(message)

        if len(parts) >= 2:
            d1 = self._resolve_driver(parts[0], drivers)
            d2 = self._resolve_driver(parts[1], drivers)
            if d1 and d2:
                data = self.data.get_h2h_drivers(d1, d2, season=season)
                return ("driver", data)
            # One resolved, one didn't -- fall through to try constructors.
            return None

        # Single entity: compare against the user's favourite driver.
        single = self._resolve_driver(message, drivers)
        if single and fav_driver:
            fav_id = self._resolve_driver(fav_driver, drivers)
            if fav_id and fav_id != single:
                data = self.data.get_h2h_drivers(single, fav_id, season=season)
                return ("driver", data)

        return None

    def _try_constructor_comparison(
        self, message: str, season: int, fav_team: str
    ) -> tuple[str, dict] | None:
        constructors = self.data.get_constructors(season=season)
        parts = self._split_entities(message)

        if len(parts) >= 2:
            t1 = self._resolve_constructor(parts[0], constructors)
            t2 = self._resolve_constructor(parts[1], constructors)
            if t1 and t2:
                data = self.data.get_h2h_constructors(t1, t2, season=season)
                return ("constructor", data)

        single = self._resolve_constructor(message, constructors)
        if single and fav_team:
            fav_id = self._resolve_constructor(fav_team, constructors)
            if fav_id and fav_id != single:
                data = self.data.get_h2h_constructors(single, fav_id, season=season)
                return ("constructor", data)

        return None

    # ------------------------------------------------------------------ #
    #  Entity resolution                                                   #
    # ------------------------------------------------------------------ #

    def _resolve_driver(self, query: str, drivers: list[dict]) -> str | None:
        """Match a driver name, code, or alias in *query*. Returns driverId or None."""
        q = query.lower().strip()

        # Expand aliases so e.g. "max" becomes "verstappen" in the search text.
        for nick, real in self._DRIVER_ALIASES.items():
            if nick in q:
                q = q.replace(nick, real)

        for driver in drivers:
            driver_id = driver.get("driverId", "").lower()
            family = driver.get("familyName", "").lower()
            # Ergast returns "driverCode"; fall back to "code"; guard against NaN floats
            raw_code = driver.get("driverCode") or driver.get("code") or ""
            code = str(raw_code).lower() if raw_code and str(raw_code) != "nan" else ""
            given = driver.get("givenName", "").lower()

            if driver_id and driver_id in q:
                return driver["driverId"]
            if family and family in q:
                return driver["driverId"]
            # 3-letter codes must be whole-word matches to avoid false positives.
            if code and len(code) == 3 and re.search(rf"\b{re.escape(code)}\b", q):
                return driver["driverId"]
            if given and given in q:
                return driver["driverId"]

        return None

    def _resolve_constructor(
        self, query: str, constructors: list[dict]
    ) -> str | None:
        """Match a constructor name or alias in *query*. Returns constructorId or None."""
        q = query.lower().strip()

        # Check aliases first -- they are more specific.
        for alias, cid in self._TEAM_ALIASES.items():
            if alias in q:
                for c in constructors:
                    if c.get("constructorId", "").lower() == cid:
                        return c["constructorId"]

        for constructor in constructors:
            cid = constructor.get("constructorId", "").lower()
            name = constructor.get("name", "").lower()

            if cid and cid in q:
                return constructor["constructorId"]
            if name and name in q:
                return constructor["constructorId"]

        return None

    # ------------------------------------------------------------------ #
    #  Message parsing                                                     #
    # ------------------------------------------------------------------ #

    def _split_entities(self, message: str) -> list[str]:
        """Split a comparison message into two entity strings."""
        text = message.strip()

        # Strip common leading phrases.
        text = self._PREFIX_PATTERNS.sub("", text).strip()

        # Remove season year so it doesn't confuse the split.
        text = self._SEASON_PATTERN.sub("", text).strip()

        # Split on the first separator found.
        parts = self._SPLIT_PATTERNS.split(text, maxsplit=1)
        parts = [p.strip() for p in parts if p.strip()]
        return parts

    def _extract_season(self, message: str) -> int:
        """Pull a four-digit season year from the message, default 2025."""
        match = self._SEASON_PATTERN.search(message)
        if match:
            return int(match.group(1))
        return 2025

    # ------------------------------------------------------------------ #
    #  Data formatting                                                     #
    # ------------------------------------------------------------------ #

    def _format_driver_h2h(self, data: dict, season: int) -> str:
        d1 = data["driver1"]
        d2 = data["driver2"]
        qh = data.get("qualifying_h2h", {})
        rh = data.get("race_h2h", {})

        lines = [
            f"HEAD-TO-HEAD: {d1['name']} vs {d2['name']} ({season} season)",
            "",
            (
                f"{d1['code']}: {d1['points']} pts | {d1['wins']} wins | "
                f"{d1['podiums']} podiums | Avg P{d1['avg_position']:.1f} | "
                f"{d1['dnfs']} DNFs"
            ),
            (
                f"{d2['code']}: {d2['points']} pts | {d2['wins']} wins | "
                f"{d2['podiums']} podiums | Avg P{d2['avg_position']:.1f} | "
                f"{d2['dnfs']} DNFs"
            ),
            "",
            (
                f"Qualifying: {d1['code']} ahead "
                f"{qh.get('driver1_ahead', 0)}x | {d2['code']} ahead "
                f"{qh.get('driver2_ahead', 0)}x"
            ),
            (
                f"Race:       {d1['code']} ahead "
                f"{rh.get('driver1_ahead', 0)}x | {d2['code']} ahead "
                f"{rh.get('driver2_ahead', 0)}x"
            ),
        ]

        # Append per-race breakdown if available.
        for d in (d1, d2):
            results = d.get("race_results", [])
            if results:
                lines.append("")
                lines.append(f"{d['code']} race-by-race:")
                for r in results:
                    lines.append(
                        f"  R{r['round']} {r['race']}: P{r['position']} "
                        f"(grid {r['grid']}, {r['points']} pts, {r['status']})"
                    )

        return "\n".join(lines)

    def _format_constructor_h2h(self, data: dict, season: int) -> str:
        t1 = data["team1"]
        t2 = data["team2"]
        qh = data.get("qualifying_h2h", {})
        rh = data.get("race_h2h", {})

        t1_label = t1.get("id", "Team1")
        t2_label = t2.get("id", "Team2")

        avg1 = t1.get("avg_best_position")
        avg2 = t2.get("avg_best_position")
        avg1_str = f"Avg P{avg1:.1f}" if avg1 is not None else "Avg P—"
        avg2_str = f"Avg P{avg2:.1f}" if avg2 is not None else "Avg P—"

        lines = [
            f"HEAD-TO-HEAD: {t1_label} vs {t2_label} ({season} season)",
            "",
            (
                f"{t1_label}: {t1.get('points', 'N/A')} pts | "
                f"{t1.get('wins', 'N/A')} wins | "
                f"{t1.get('podiums', 'N/A')} podiums | "
                f"{avg1_str} | "
                f"{t1.get('dnfs', 0)} DNFs"
            ),
            (
                f"{t2_label}: {t2.get('points', 'N/A')} pts | "
                f"{t2.get('wins', 'N/A')} wins | "
                f"{t2.get('podiums', 'N/A')} podiums | "
                f"{avg2_str} | "
                f"{t2.get('dnfs', 0)} DNFs"
            ),
            "",
            (
                f"Qualifying: {t1_label} ahead "
                f"{qh.get('team1_ahead', 0)}x | "
                f"{t2_label} ahead "
                f"{qh.get('team2_ahead', 0)}x"
            ),
            (
                f"Race:       {t1_label} ahead "
                f"{rh.get('team1_ahead', 0)}x | "
                f"{t2_label} ahead "
                f"{rh.get('team2_ahead', 0)}x"
            ),
        ]

        # Append per-race breakdown using best_finish_per_race.
        for label, team in [("team1", t1), ("team2", t2)]:
            races = team.get("best_finish_per_race", [])
            if races:
                lines.append("")
                lines.append(f"{team.get('id', label)} race-by-race:")
                for r in races:
                    lines.append(
                        f"  R{r['round']} {r['race_name']}: "
                        f"Best P{r['best_position']} ({r['points']} pts)"
                    )

        return "\n".join(lines)

    # ------------------------------------------------------------------ #
    #  LLM call                                                            #
    # ------------------------------------------------------------------ #

    def _generate_response(
        self,
        formatted_data: str,
        history: list,
        user_message: str,
        fav_driver: str,
        fav_team: str,
    ) -> str:
        system_prompt = (
            "You are Pitwall's Head-to-Head analyst. You compare F1 drivers "
            "and teams using real data.\n"
            "Present comparisons clearly with key stats highlighted.\n"
            "Be objective but engaging. Use the data provided to support "
            "your analysis.\n"
            "When relevant, mention qualifying pace vs race pace, "
            "consistency, and DNF impact.\n"
            "Keep responses concise but informative — around 150-250 words.\n"
            f"The user's favourite driver is "
            f"{fav_driver or 'not specified'} and favourite team is "
            f"{fav_team or 'not specified'}."
        )

        # Carry over recent conversation history then append current turn.
        messages: list[dict] = []
        for entry in history[-6:]:
            messages.append({"role": entry["role"], "content": entry["content"]})

        user_content = (
            f"User question: {user_message}\n\n"
            f"Here is the data for the comparison:\n\n{formatted_data}"
        )
        messages.append({"role": "user", "content": user_content})

        return self._call_llm(system_prompt, messages)
