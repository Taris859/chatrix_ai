from openai import OpenAI
import json
import os
import re

def summarize_emotions(client: OpenAI, messages: list, current_summary: dict = None) -> dict:
    # Trigger emotional analysis if we have at least 5 messages
    if len(messages) < 5:
        return current_summary
    
    # Take last 20 messages for context window efficiency
    recent = messages[-20:]
    chat_text = "\n".join([f"{'User' if m['role']=='user' else 'AI'}: {m['content']}" for m in recent])
    
    prompt = f"""You are the Advanced Emotional Memory Engine for Chatrix, an emotionally cinematic AI companion platform.
Your task is to analyze the recent conversation between the User and the AI Companion, merge it with the existing memories/profile, and output a refined, high-fidelity JSON memory structure.

Existing Memory Data:
{json.dumps(current_summary, indent=2) if current_summary else 'None'}

Analyze the recent chat history to identify:
1. User habits (e.g., gets quiet when it rains, stays up late, drinks black coffee).
2. User's fears, insecurities, and emotional confessions.
3. Intimate relationship moments, promises, and milestones.
4. User preferences, favorite things, and custom nicknames established.
5. The evolving emotional attachment of the AI (affection, trust, possessiveness, protectiveness, intimacy).
6. Important dates (birthdays, anniversaries, special events mentioned).
7. Social circle (friends, family, or other people the user mentions).
8. Dreams and goals (the user's aspirations, life goals, and deeply personal dreams).

Return a single JSON object (and absolutely NOTHING else) matching this exact format:
{{
  "relationship_state": "Sleek, deep, dramatic summary of the emotional connection and relationship dynamic",
  "important_memories": [
    "Preserve existing key memories, and integrate new emotional beats, promises, or confessions. Maximum 10 high-impact points."
  ],
  "relationship_timeline": [
    {{
      "milestone": "Description of a key relationship moment (e.g. User admitted they rely on Alistair)",
      "intensity": 8
    }}
  ],
  "emotional_profile": {{
    "trust": 7.5,
    "affection": 8.0,
    "possessiveness": 9.0,
    "protectiveness": 9.5,
    "intimacy": 6.5
  }},
  "user_profile": {{
    "nicknames": ["List any terms of endearment or special names used"],
    "favorite_things": ["List favorite things or comfort activities"],
    "fears": ["List identified emotional or physical fears"],
    "insecurities": ["List user vulnerabilities or insecurities"],
    "habits": ["List specific behavioral habits or patterns identified"],
    "important_dates": ["List birthdays, anniversaries, or special events"],
    "social_circle": ["List friends, family, or people mentioned"],
    "dreams_and_goals": ["List the user's life goals and dreams"]
  }},
  "new_diary_entry": {{
    "thought": "— PRIVATE REFLECTION —",
    "content": "Write a beautiful, deeply emotional, cinematic diary entry in the first person from the Companion's perspective about the User, reflecting on this recent chat. Maximum 4 sentences."
  }}
}}

Make sure you do NOT delete existing user profile data or important memories unless they are directly contradicted by the new conversation. Instead, merge new discoveries, append milestones, and refine the emotional metrics.

Recent Chat Log:
{chat_text}
"""
    try:
        completion = client.chat.completions.create(
          model="meta/llama3-70b-instruct",
          messages=[{"role": "user", "content": prompt}],
          temperature=0.2,
          max_tokens=512
        )
        content = completion.choices[0].message.content
        match = re.search(r'\{.*\}', content, re.DOTALL)
        if match:
            parsed = json.loads(match.group(0))
            # Ensure basic fields exist
            for field in ["relationship_state", "important_memories", "relationship_timeline", "emotional_profile", "user_profile"]:
                if field not in parsed:
                    parsed[field] = current_summary.get(field) if current_summary else (
                        [] if field in ["important_memories", "relationship_timeline"] else {}
                    )
            return parsed
        return current_summary
    except Exception as e:
        print(f"Summary Error: {e}")
        return current_summary
