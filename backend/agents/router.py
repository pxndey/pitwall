"""Agent Router — classifies user intent and delegates to the appropriate agent."""

from __future__ import annotations

from agents.briefing import BriefingAgent
from agents.data_service import F1DataService
from agents.h2h import H2HAgent


class AgentRouter:
    """Classifies user intent and routes to the appropriate agent."""

    def __init__(self) -> None:
        self.data_service = F1DataService()
        self.agents = [
            H2HAgent(self.data_service),
            BriefingAgent(self.data_service),
        ]
        self._fallback = BriefingAgent(self.data_service)  # default

    def classify_intent(self, message: str) -> str:
        """Classify the user's message into an intent category.

        Returns one of: ``'h2h'``, ``'briefing'``, ``'general'``.

        Uses keyword matching first (fast); falls back to ``'general'``
        which the briefing agent handles as a catch-all.
        """
        msg_lower = message.lower()

        # H2H keywords
        h2h_keywords = [
            "head to head", "h2h", "versus", " vs ", "compare", "comparison",
            "better than", "who is faster", "who beats", "matchup",
        ]
        if any(kw in msg_lower for kw in h2h_keywords):
            return "h2h"

        # Briefing / info keywords (broad)
        briefing_keywords = [
            "standings", "championship", "pole", "qualifying", "race result",
            "summary", "briefing", "what happened", "session", "practice",
            "explain", "what is", "what does", "terminology", "meaning",
            "history", "my team", "my driver", "drs", "tyre", "tire",
            "strategy", "pit stop", "undercut", "overcut", "safety car",
        ]
        if any(kw in msg_lower for kw in briefing_keywords):
            return "briefing"

        return "general"  # falls back to briefing agent for F1 context

    def route(self, message: str, history: list, user_context: dict) -> str:
        """Route to the appropriate agent and return the response."""
        intent = self.classify_intent(message)

        for agent in self.agents:
            if agent.can_handle(message, intent):
                return agent.handle(message, history, user_context)

        return self._fallback.handle(message, history, user_context)
