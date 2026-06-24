import os
def load_env():
    if os.path.exists('.env'):
        with open('.env', 'r') as f:
            for line in f:
                if line.startswith('GEMINI_API_KEY='):
                    return line.strip().split('=', 1)[1].strip('"').strip("'")
    return None
api_key = load_env()
from google import genai
client = genai.Client(api_key=api_key)
for m in client.models.list():
    print(m.name)
