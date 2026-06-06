from fastapi import HTTPException
from memory.memory_manager import add_message, get_session_data, get_chat_history, update_session_data, check_message_limit, increment_message_count
from services.prompt_injector import build_system_prompt
from services.emotional_summarizer import summarize_emotions
from services.llm_service import LLMService

class MemoryService:
    @staticmethod
    def get_history(user_id: str, companion_name: str):
        return {"messages": get_chat_history(user_id, companion_name)}

    @staticmethod
    def get_memory(user_id: str, companion_name: str):
        session_data = get_session_data(user_id, companion_name)
        return {
            "summary": session_data.get("summary"),
            "diary_entries": session_data.get("diary_entries", [])
        }

    @staticmethod
    async def process_chat(message: str, user_id: str, companion_name: str, companion_archetype: str, companion_personality: str = "", companion_greeting: str = "", scene_context: str = "", is_premium: bool = False):
        try:
            if not check_message_limit(user_id, is_premium):
                return {"response": "The connection fades... You have reached your daily message limit. Upgrade to Chatrix Premium to unlock unlimited messaging and deeper emotional immersion."}

            # Load Memory
            session_data = get_session_data(user_id, companion_name)
            messages = session_data.get("messages", [])
            
            # Seed cinematic greeting if history is empty
            if not messages and companion_greeting:
                greeting_msg = {"role": "assistant", "content": companion_greeting}
                add_message(user_id, companion_name, greeting_msg)
                messages.append(greeting_msg)
            
            # Save user message
            user_msg = {"role": "user", "content": message}
            add_message(user_id, companion_name, user_msg)
            messages.append(user_msg)

            # Build system prompt
            system_prompt = build_system_prompt(
                companion_name, 
                companion_archetype, 
                companion_personality,
                companion_greeting,
                session_data,
                scene_context,
                is_premium
            )

            # Build context for LLM
            llm_messages = [{"role": "system", "content": system_prompt}]
            recent_history = messages[-10:] if len(messages) > 10 else messages
            llm_messages.extend(recent_history)

            # Call LLM Service with multi-provider fallbacks
            reply = await LLMService.generate_response(llm_messages, is_premium=is_premium)

            # Save AI response
            ai_msg = {"role": "assistant", "content": reply}
            add_message(user_id, companion_name, ai_msg)
            messages.append(ai_msg)

            # Trigger emotional summaries
            if len(messages) % 10 == 0:
                # To maintain summarize_emotions compatibility, we fetch raw openAI client
                # using LLMService details as fallback, or invoke inline.
                from openai import OpenAI
                import os
                # Lightweight summarization client
                summary_client = OpenAI(
                    base_url="https://integrate.api.nvidia.com/v1",
                    api_key=os.getenv("NVIDIA_API_KEY", "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")
                )
                new_summary = summarize_emotions(summary_client, messages, session_data.get("summary"))
                if new_summary:
                    diary_entry = new_summary.pop("new_diary_entry", None)
                    update_session_data(user_id, companion_name, summary=new_summary, diary_entry=diary_entry)

            # Return updated logs
            updated_session_data = get_session_data(user_id, companion_name)
            increment_message_count(user_id)

            return {
                "response": reply,
                "memory": updated_session_data.get("summary"),
                "diary_entries": updated_session_data.get("diary_entries", [])
            }
        except Exception as e:
            print(f"MemoryService Chat Error: {e}")
            raise HTTPException(status_code=500, detail="Failed to connect to the Soul Engine.")
