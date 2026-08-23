with open(r'C:\Users\user\.local\share\opencode\tool-output\tool_024cc7196001EdQguHRKMbPhXO', 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

import re

# Find all sections between [Name](/model/...) and the next such link
cards = re.split(r'(?=\[![^\]]+\]\(https://assets[^)]+\))', content)
print(f"Split into {len(cards)} chunks")

# Let's manually scan for key price patterns
price_lines = []
for line in content.split('\n'):
    if 'Input:' in line or 'Output:' in line or 'Web Search' in line or 'Image' in line or 'Free' in line:
        price_lines.append(line)

print(f"\nFound {len(price_lines)} price-related lines:")
for line in price_lines[:80]:
    clean = line.replace('<', '').replace('>', '').replace('**', '').strip()
    if len(clean) < 300:
        print(clean)
