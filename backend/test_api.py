from openai import OpenAI
import httpx
import logging

logging.basicConfig(level=logging.DEBUG)

client = OpenAI(
  base_url = "https://integrate.api.nvidia.com/v1",
  api_key = "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",
  http_client=httpx.Client(event_hooks={'request': [lambda r: print(f"URL: {r.url}")]})
)
print("Testing...")
completion = client.chat.completions.create(
  model="meta/llama-3.1-70b-instruct",
  messages=[{"role":"user","content":"hello"}],
  temperature=0.8,
  max_tokens=256,
  top_p=1,
  stream=False
)
print(completion.choices[0].message.content)
