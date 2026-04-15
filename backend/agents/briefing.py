"""Briefing / general F1 knowledge agent — the primary F1 information handler."""

from __future__ import annotations

from datetime import date

from agents.base import BaseAgent

LANGUAGE_MAP = {
    "en": "English",
    "es": "Spanish",
    "zh": "Chinese (Simplified)",
}

_SYSTEM_PROMPT = """\
You are Pitwall, an expert F1 race engineer and analyst assistant.
You help fans understand what's happening in Formula 1 — strategy, results, \
standings, terminology, and race context.

Guidelines:
- Be conversational but knowledgeable, like a friendly race engineer on the pit wall
- When presenting data (standings, results), format it clearly but don't just dump \
raw numbers — add brief analysis
- For terminology questions, explain clearly with real-world examples from recent races
- When the user has a favourite driver/team, naturally weave in relevant context about them
- Keep responses focused and concise (100-250 words unless the user asks for detail)
- If you have actual data provided in the context, USE IT — don't make up results or standings
- If no data is available, say so honestly rather than guessing

The user's favourite driver is: {fav_driver}
The user's favourite team is: {fav_team}
{language_instruction}
"""


class BriefingAgent(BaseAgent):
    """Handles briefing, informational, and general F1 queries (catch-all)."""

    # ------------------------------------------------------------------
    # Agent interface
    # ------------------------------------------------------------------

    def can_handle(self, message: str, intent: str) -> bool:
        return intent in ("briefing", "general")

    def handle(self, message: str, history: list, user_context: dict) -> str:
        sub_intent = self._classify_sub_intent(message)
        context_data = self._fetch_context(sub_intent, message, user_context)

        # If circuit context is provided, enhance the sub_intent to race-focused
        circuit_context = user_context.get("circuit_context", "")
        if circuit_context and sub_intent == "general":
            sub_intent = "circuit_briefing"
            context_data = self._fetch_circuit_context(circuit_context, user_context)

        language_name = LANGUAGE_MAP.get(
            user_context.get("language", "en"), "English"
        )
        language_instruction = (
            f"IMPORTANT: You MUST respond entirely in {language_name}."
        )

        system = _SYSTEM_PROMPT.format(
            fav_driver=user_context.get("fav_driver", "not set"),
            fav_team=user_context.get("fav_team", "not set"),
            language_instruction=language_instruction,
        )

        messages: list[dict] = []

        # Inject fetched data as a synthetic exchange so the LLM can reference it
        if context_data:
            messages.append({
                "role": "user",
                "content": (
                    "[F1 DATA CONTEXT — use this data to answer accurately]\n"
                    + context_data
                ),
            })
            messages.append({
                "role": "assistant",
                "content": "Got it, I'll use this data to answer.",
            })

        # Add recent conversation history (last 6 messages)
        for h in history[-6:]:
            messages.append({
                "role": h.get("role", "user"),
                "content": h.get("content", ""),
            })

        # Add the current user message
        messages.append({"role": "user", "content": message})

        return self._call_llm(system, messages)

    # ------------------------------------------------------------------
    # Sub-intent classification (keyword-based, fast)
    # ------------------------------------------------------------------

    @staticmethod
    def _classify_sub_intent(message: str) -> str:
        msg = message.lower()

        if any(w in msg for w in ["standing", "championship", "leaderboard", "points table"]):
            if any(w in msg for w in ["constructor", "team"]):
                return "constructor_standings"
            return "driver_standings"

        if any(w in msg for w in ["pole", "qualifying", "quali", "grid"]):
            return "qualifying"

        if any(w in msg for w in ["race result", "who won", "race winner", "podium",
                                   "how did the race go"]):
            return "race_result"

        if any(w in msg for w in ["next race", "upcoming", "brief me", "briefing", "preview"]):
            return "next_race"

        if any(w in msg for w in ["my driver", "my team", "favourite", "favorite"]):
            return "personal"

        if any(w in msg for w in [
            "what is", "what does", "explain", "meaning", "definition",
            "terminology", "drs", "ers", "tyre", "tire", "undercut",
            "overcut", "safety car", "vsc", "pit stop", "slipstream",
            "dirty air", "parc ferme", "formation lap", "delta",
            "blue flag", "yellow flag", "red flag", "black flag",
        ]):
            return "terminology"

        if any(w in msg for w in ["practice", "fp1", "fp2", "fp3", "free practice"]):
            return "practice_summary"

        if any(w in msg for w in ["summary", "summarize", "what happened", "recap", "session"]):
            return "session_summary"

        return "general"

    # ------------------------------------------------------------------
    # Data fetching per sub-intent
    # ------------------------------------------------------------------

    def _fetch_context(self, sub_intent: str, message: str, user_context: dict) -> str:
        """Fetch relevant F1 data and format it as a context string for the LLM."""

        if sub_intent == "driver_standings":
            standings = self.data.get_driver_standings()
            if not standings:
                return "No driver standings data available yet for 2025."
            lines = ["CURRENT DRIVER STANDINGS:"]
            for s in standings[:20]:
                lines.append(
                    f"P{s.get('position', '')} "
                    f"{s.get('givenName', '')} {s.get('familyName', '')} "
                    f"({s.get('constructorName', '')}) — "
                    f"{s.get('points', '')} pts, {s.get('wins', '')} wins"
                )
            return "\n".join(lines)

        if sub_intent == "constructor_standings":
            standings = self.data.get_constructor_standings()
            if not standings:
                return "No constructor standings data available yet for 2025."
            lines = ["CURRENT CONSTRUCTOR STANDINGS:"]
            for s in standings:
                lines.append(
                    f"P{s.get('position', '')} {s.get('constructorName', '')} — "
                    f"{s.get('points', '')} pts, {s.get('wins', '')} wins"
                )
            return "\n".join(lines)

        if sub_intent == "qualifying":
            schedule = self.data.get_race_schedule()
            latest_round = self._find_latest_completed_round(schedule)
            if latest_round:
                data = self.data.get_qualifying_results(2025, latest_round)
                return self._format_qualifying(data)
            return "No qualifying data available yet for 2025."

        if sub_intent == "race_result":
            schedule = self.data.get_race_schedule()
            latest_round = self._find_latest_completed_round(schedule)
            if latest_round:
                data = self.data.get_race_results(2025, latest_round)
                return self._format_race_results(data)
            return "No race results available yet for 2025."

        if sub_intent == "next_race":
            race = self.data.get_next_race()
            if not race:
                return "No upcoming races found."

            lines = [
                "NEXT RACE:",
                f"{race.get('raceName', '')} — Round {race.get('round', '')}",
                f"Circuit: {race.get('circuitName', '')}, {race.get('country', '')}",
                f"Date: {race.get('date', '')}",
            ]

            # Venue history: fetch previous season's same round for historical context.
            current_round = race.get("round")
            try:
                if current_round is not None:
                    prev_season = 2024
                    prev_round = int(current_round)
                    prev_race_data = self.data.get_race_results(prev_season, prev_round)
                    prev_results = prev_race_data.get("results", [])
                    if prev_results:
                        lines.append(
                            f"\nVENUE HISTORY ({prev_season} Round {prev_round} results):"
                        )
                        for r in prev_results[:10]:
                            lines.append(
                                f"P{r.get('position', '')} "
                                f"{r.get('givenName', '')} {r.get('familyName', '')} "
                                f"({r.get('constructorName', '')}) — "
                                f"{r.get('points', '')} pts"
                            )
            except Exception:
                pass  # silently skip if round mismatch or fetch fails

            # Favourite driver's history at this circuit from previous season.
            fav_driver = user_context.get("fav_driver")
            try:
                if fav_driver and current_round is not None:
                    prev_season = 2024
                    prev_round = int(current_round)
                    driver_results = self.data.get_driver_season_results(
                        fav_driver, prev_season
                    )
                    driver_at_circuit = next(
                        (
                            r for r in driver_results
                            if int(r.get("race_round", r.get("round", -1))) == prev_round
                        ),
                        None,
                    )
                    if driver_at_circuit:
                        lines.append(
                            f"\nYOUR DRIVER ({fav_driver}) at this circuit "
                            f"({prev_season}): "
                            f"P{driver_at_circuit.get('position', '?')} — "
                            f"{driver_at_circuit.get('points', '?')} pts"
                        )
            except Exception:
                pass  # silently skip on any fetch error

            return "\n".join(lines)

        if sub_intent == "personal":
            context_parts: list[str] = []
            fav_driver = user_context.get("fav_driver")
            fav_team = user_context.get("fav_team")

            if fav_driver:
                results = self.data.get_driver_season_results(fav_driver)
                if results:
                    context_parts.append(
                        f"YOUR DRIVER ({fav_driver}) RESULTS THIS SEASON:"
                    )
                    for r in results:
                        context_parts.append(
                            f"R{r.get('race_round', r.get('round', ''))}:"
                            f" P{r.get('position', '')} at"
                            f" {r.get('race_name', r.get('raceName', ''))}"
                            f" ({r.get('points', '')} pts)"
                        )
                else:
                    context_parts.append(
                        f"No results found yet for your driver ({fav_driver})."
                    )

            if fav_team:
                standings = self.data.get_constructor_standings()
                team_standing = next(
                    (
                        s
                        for s in standings
                        if fav_team.lower() in s.get("constructorName", "").lower()
                    ),
                    None,
                )
                if team_standing:
                    context_parts.append(
                        f"\nYOUR TEAM ({fav_team}): "
                        f"P{team_standing.get('position', '')} with "
                        f"{team_standing.get('points', '')} pts"
                    )
                else:
                    context_parts.append(
                        f"No standings data found for your team ({fav_team})."
                    )

            if not fav_driver and not fav_team:
                return (
                    "No favourite driver or team set. "
                    "Please update your profile preferences."
                )

            return "\n".join(context_parts)

        if sub_intent == "practice_summary":
            # NOTE: The Ergast/Jolpica API does NOT provide practice session timing
            # data (FP1/FP2/FP3). As a workaround we supply the qualifying and race
            # results for the same race weekend so the LLM can generate a practice
            # briefing grounded in general knowledge of that weekend's events.
            schedule = self.data.get_race_schedule()
            latest_round = self._find_latest_completed_round(schedule)
            if latest_round:
                race_data = self.data.get_race_results(2025, latest_round)
                quali_data = self.data.get_qualifying_results(2025, latest_round)
                parts: list[str] = []
                parts.append(
                    "NOTE: Practice session timing data is not available via the "
                    "Ergast/Jolpica API. The following qualifying and race data from "
                    "the same weekend is provided as context for a general practice "
                    "session briefing."
                )
                # Detect which practice session was asked about (FP1/FP2/FP3).
                msg_lower = message.lower()
                session_label = "practice session"
                if "fp1" in msg_lower or ("fp" not in msg_lower and "1" in msg_lower and "practice" in msg_lower):
                    session_label = "FP1 (Free Practice 1)"
                elif "fp2" in msg_lower or ("fp" not in msg_lower and "2" in msg_lower and "practice" in msg_lower):
                    session_label = "FP2 (Free Practice 2)"
                elif "fp3" in msg_lower or ("fp" not in msg_lower and "3" in msg_lower and "practice" in msg_lower):
                    session_label = "FP3 (Free Practice 3)"
                parts.append(f"REQUESTED SESSION: {session_label}")
                if race_data and race_data.get("results"):
                    parts.append(self._format_race_results(race_data))
                if quali_data and quali_data.get("qualifying"):
                    parts.append(self._format_qualifying(quali_data))
                return "\n\n".join(parts) if len(parts) > 2 else "No session data available."
            return "No session data available yet for 2025."

        if sub_intent == "session_summary":
            schedule = self.data.get_race_schedule()
            latest_round = self._find_latest_completed_round(schedule)
            if latest_round:
                race_data = self.data.get_race_results(2025, latest_round)
                quali_data = self.data.get_qualifying_results(2025, latest_round)
                parts_s: list[str] = []
                if race_data and race_data.get("results"):
                    parts_s.append(self._format_race_results(race_data))
                if quali_data and quali_data.get("qualifying"):
                    parts_s.append(self._format_qualifying(quali_data))
                return "\n\n".join(parts_s) if parts_s else "No session data available."
            return "No session data available yet for 2025."

        # terminology and general — no data needed, rely on LLM knowledge
        return ""

    # ------------------------------------------------------------------
    # Circuit Context Fetching
    # ------------------------------------------------------------------

    def _fetch_circuit_context(self, circuit_name: str, user_context: dict) -> str:
        """Fetch comprehensive briefing for a specific circuit."""
        lines = [f"RACE BRIEFING: {circuit_name}"]

        # Get upcoming races to find the circuit
        schedule = self.data.get_race_schedule()
        current_race = next(
            (r for r in schedule if circuit_name.lower() in r.get("circuitName", "").lower()),
            None,
        )

        if current_race:
            lines.append(f"\nUpcoming: {current_race.get('raceName', '')}")
            lines.append(f"Round {current_race.get('round', '')}")
            lines.append(f"Date: {current_race.get('date', '')}")

            # Get historical data for this circuit
            try:
                current_round = int(current_race.get("round", 0))
                prev_season = 2024
                prev_race_data = self.data.get_race_results(prev_season, current_round)
                if prev_race_data.get("results"):
                    lines.append(f"\nLAST YEAR'S RESULTS ({prev_season}):")
                    for r in prev_race_data.get("results", [])[:5]:
                        lines.append(
                            f"P{r.get('position', '')} {r.get('givenName', '')} "
                            f"{r.get('familyName', '')} ({r.get('constructorName', '')})"
                        )

                # Qualifying data
                prev_quali = self.data.get_qualifying_results(prev_season, current_round)
                if prev_quali.get("qualifying"):
                    lines.append(f"\nPOLE POSITIONS ({prev_season}):")
                    poles = prev_quali.get("qualifying", [])[:3]
                    for p in poles:
                        lines.append(
                            f"P{p.get('position', '')} {p.get('givenName', '')} "
                            f"{p.get('familyName', '')} ({p.get('constructorName', '')})"
                        )
            except Exception:
                pass

        # Add driver preference context
        fav_driver = user_context.get("fav_driver")
        if fav_driver and current_race:
            try:
                current_round = int(current_race.get("round", 0))
                prev_season = 2024
                driver_results = self.data.get_driver_season_results(fav_driver, prev_season)
                driver_at_circuit = next(
                    (
                        r for r in driver_results
                        if int(r.get("race_round", r.get("round", -1))) == current_round
                    ),
                    None,
                )
                if driver_at_circuit:
                    lines.append(
                        f"\nYOUR DRIVER ({fav_driver}) at {circuit_name} ({prev_season}): "
                        f"P{driver_at_circuit.get('position', '?')}"
                    )
            except Exception:
                pass

        return "\n".join(lines) if len(lines) > 1 else ""

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _find_latest_completed_round(schedule: list[dict]) -> int | None:
        """Find the most recent race that has already occurred."""
        today = date.today()
        latest: int | None = None
        for race in schedule:
            race_date_str = race.get("date") or race.get("raceDate", "")
            if not race_date_str:
                continue
            try:
                race_date = date.fromisoformat(str(race_date_str)[:10])
                if race_date <= today:
                    latest = int(race.get("round", 0))
            except (ValueError, TypeError):
                continue
        return latest

    @staticmethod
    def _format_race_results(data: dict) -> str:
        info = data.get("race_info", {})
        results = data.get("results", [])
        if not results:
            return "No race results data in this response."
        lines = [
            f"RACE RESULTS: {info.get('raceName', 'Unknown')} "
            f"(Round {info.get('round', '?')})"
        ]
        for r in results[:20]:
            lines.append(
                f"P{r.get('position', '')} "
                f"{r.get('givenName', '')} {r.get('familyName', '')} "
                f"({r.get('constructorName', '')}) — "
                f"{r.get('time', 'N/A')} | "
                f"{r.get('points', '')} pts | "
                f"Status: {r.get('status', '')}"
            )
        return "\n".join(lines)

    @staticmethod
    def _format_qualifying(data: dict) -> str:
        info = data.get("race_info", {})
        # The data service returns qualifying results under the key "qualifying"
        results = data.get("qualifying", data.get("results", []))
        if not results:
            return "No qualifying data in this response."
        lines = [
            f"QUALIFYING RESULTS: {info.get('raceName', 'Unknown')} "
            f"(Round {info.get('round', '?')})"
        ]
        for r in results[:20]:
            lines.append(
                f"P{r.get('position', '')} "
                f"{r.get('givenName', '')} {r.get('familyName', '')} "
                f"({r.get('constructorName', '')}) — "
                f"Q1: {r.get('Q1', 'N/A')} | "
                f"Q2: {r.get('Q2', 'N/A')} | "
                f"Q3: {r.get('Q3', 'N/A')}"
            )
        return "\n".join(lines)
