"""Base agent class for all PitCrew agents."""

from __future__ import annotations

from abc import ABC, abstractmethod


class BaseAgent(ABC):
    """Base class for all PitCrew agents."""

    def __init__(self, data_service) -> None:
        self.data = data_service

    @abstractmethod
    def can_handle(self, message: str, intent: str) -> bool:
        """Whether this agent should handle this query."""

    @abstractmethod
    def handle(self, message: str, history: list, user_context: dict) -> str:
        """Process the message and return a text response.

        Args:
            message: The user's current message.
            history: Conversation history as ``[{role: str, content: str}, ...]``.
            user_context: Dict with ``{username, fav_driver, fav_team}``.
        """

    def _call_llm(self, system_prompt: str, messages: list[dict]) -> str:
        """Call watsonx LLM and return the response text.

        Args:
            system_prompt: The system-level instruction for the model.
            messages: ``[{role: 'user'|'assistant'|'system', content: str}, ...]``
        """
        try:
            from ibm_watsonx_ai import Credentials
            from ibm_watsonx_ai.foundation_models import ModelInference

            from core.config import settings

            if not settings.watsonx_api_key or not settings.watsonx_project_id:
                return "PitCrew AI is not configured."

            credentials = Credentials(
                url=settings.watsonx_url,
                api_key=settings.watsonx_api_key,
            )
            model = ModelInference(
                model_id="meta-llama/llama-3-3-70b-instruct",
                credentials=credentials,
                project_id=settings.watsonx_project_id,
            )

            full_messages = [{"role": "system", "content": system_prompt}] + messages
            response = model.chat(messages=full_messages)

            return (
                response.get("choices", [{}])[0]
                .get("message", {})
                .get("content", "")
                .strip()
            ) or "No response received."

        except Exception as e:
            return f"PitCrew AI error: {e}"

    def _call_llm_stream(self, system_prompt: str, messages: list[dict]):
        """Yield response tokens from watsonx LLM."""
        try:
            from ibm_watsonx_ai import Credentials
            from ibm_watsonx_ai.foundation_models import ModelInference

            from core.config import settings

            if not settings.watsonx_api_key or not settings.watsonx_project_id:
                yield "PitCrew AI is not configured."
                return

            credentials = Credentials(
                url=settings.watsonx_url,
                api_key=settings.watsonx_api_key,
            )
            model = ModelInference(
                model_id="meta-llama/llama-3-3-70b-instruct",
                credentials=credentials,
                project_id=settings.watsonx_project_id,
            )

            full_messages = [{"role": "system", "content": system_prompt}] + messages
            for chunk in model.chat_stream(messages=full_messages):
                delta = (
                    chunk.get("choices", [{}])[0]
                    .get("delta", {})
                    .get("content", "")
                )
                if delta:
                    yield delta

        except Exception as e:
            yield f"PitCrew AI error: {e}"

    def handle_stream(self, message: str, history: list, user_context: dict):
        """Stream response tokens. Default: yield full response."""
        yield self.handle(message, history, user_context)
