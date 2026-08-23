with open(r'C:\Users\user\.local\share\opencode\tool-output\tool_024cc7196001EdQguHRKMbPhXO', 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()
print("Length:", len(content))
import re
model_links = re.findall(r'\[([^\]]+)\]\(/model/[^)]+\)', content)
print(f"Found {len(model_links)} model links")
for i, name in enumerate(model_links[:50]):
    print(f"{i+1:03d}: {name}")
