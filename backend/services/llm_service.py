import os
import httpx
from fastapi import HTTPException

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY") or os.getenv("GEMINI_KEY")
DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY")

class LLMService:
    @staticmethod
    def get_nvidia_keys() -> list[str]:
        keys_str = os.getenv("NVIDIA_API_KEYS")
        if keys_str:
            return [k.strip() for k in keys_str.split(",") if k.strip()]
        single_key = os.getenv("NVIDIA_API_KEY")
        if single_key:
            return [single_key.strip()]
        return []

    @staticmethod
    async def generate_response(messages: list, model_name: str = "meta/llama3-70b-instruct", is_premium: bool = False) -> str:
        # Fallback chain: Nvidia Llama -> Gemini -> DeepSeek
        errors = []

        # 1. Try Nvidia Llama (with key rotation)
        nvidia_keys = LLMService.get_nvidia_keys()
        for idx, key in enumerate(nvidia_keys):
            try:
                async with httpx.AsyncClient() as client:
                    headers = {
                        "Content-Type": "application/json",
                        "Authorization": f"Bearer {key}"
                    }
                    payload = {
                        "model": model_name,
                        "messages": messages,
                        "temperature": 0.8,
                        "max_tokens": 512,
                        "top_p": 1.0,
                        "stream": False
                    }
                    response = await client.post(
                        "https://integrate.api.nvidia.com/v1/chat/completions",
                        json=payload,
                        headers=headers,
                        timeout=30.0
                    )
                    if response.status_code == 200:
                        data = response.json()
                        return data['choices'][0]['message']['content']
                    else:
                        print(f"[Key Rotation LLMService] Key #{idx+1} failed with status {response.status_code}. Detail: {response.text}")
                        errors.append(f"Nvidia Key #{idx+1} status: {response.status_code}")
            except Exception as e:
                print(f"[Key Rotation LLMService] Key #{idx+1} exception: {e}")
                errors.append(f"Nvidia Key #{idx+1} Exception: {str(e)}")

        # 2. Try Gemini API fallback (if GEMINI_API_KEY is available)
        if GEMINI_API_KEY:
            try:
                gemini_contents = []
                system_instruction = ""
                for msg in messages:
                    if msg["role"] == "system":
                        system_instruction = msg["content"]
                    else:
                        role = "model" if msg["role"] == "assistant" else "user"
                        gemini_contents.append({
                            "role": role,
                            "parts": [{"text": msg["content"]}]
                        })

                async with httpx.AsyncClient() as client:
                    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={GEMINI_API_KEY}"
                    payload = {
                        "contents": gemini_contents,
                        "generationConfig": {
                            "temperature": 0.8,
                            "maxOutputTokens": 512
                        }
                    }
                    if system_instruction:
                        payload["systemInstruction"] = {
                            "parts": [{"text": system_instruction}]
                        }
                    response = await client.post(url, json=payload, timeout=25.0)
                    if response.status_code == 200:
                        data = response.json()
                        return data["candidates"][0]["content"]["parts"][0]["text"]
                    else:
                        errors.append(f"Gemini status code: {response.status_code}")
            except Exception as e:
                errors.append(f"Gemini Exception: {str(e)}")

        # 3. Try DeepSeek API fallback (if DEEPSEEK_API_KEY is available)
        if DEEPSEEK_API_KEY:
            try:
                async with httpx.AsyncClient() as client:
                    headers = {
                        "Content-Type": "application/json",
                        "Authorization": f"Bearer {DEEPSEEK_API_KEY}"
                    }
                    payload = {
                        "model": "deepseek-chat",
                        "messages": messages,
                        "temperature": 0.8,
                        "max_tokens": 512
                    }
                    response = await client.post(
                        "https://api.deepseek.com/v1/chat/completions",
                        json=payload,
                        headers=headers,
                        timeout=25.0
                    )
                    if response.status_code == 200:
                        data = response.json()
                        return data['choices'][0]['message']['content']
                    else:
                        errors.append(f"DeepSeek status code: {response.status_code}")
            except Exception as e:
                errors.append(f"DeepSeek Exception: {str(e)}")

        # If all failed, log and throw
        print(f"LLM Registry Fallback Failure chain: {errors}")
        raise HTTPException(status_code=500, detail="Failed to communicate with LLM cluster. Fallback chain exhausted.")
