with open(r'C:\Users\user\.local\share\opencode\tool-output\tool_024cc7196001EdQguHRKMbPhXO', 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

import re

# Find all Input: positions and extract cards
input_positions = [m.start() for m in re.finditer('Input:', content)]
print(f"Input: count = {len(input_positions)}")

results = []
for pos in input_positions:
    before = content[max(0, pos-350):pos]
    after = content[pos:min(len(content), pos+300)]
    # Find model name (last link before Input)
    before_links = re.findall(r'\[([^\]]+)\]\(/model/[^)]+\)', before)
    name = before_links[-1] if before_links else "Unknown"
    # Find last model link slug
    slug_match = re.search(r'/model/([^)]+)', before)
    slug = slug_match.group(1) if slug_match else ""
    combined = (before[-250:] + after[:200]).replace('<','').replace('>','')
    combined = ' '.join(combined.split())
    results.append((name, slug, combined))

# Show unique by name, first 60
seen = set()
count = 0
for name, slug, text in results:
    key = name
    if key not in seen and count < 70:
        seen.add(key)
        count += 1
        input_match = re.search(r'Input:[^$]*\$?\s*([0-9./]+)', text)
        out_match = re.search(r'Output:[^$]*\$?\s*([0-9./]+)', text)
        ctx_match = re.search(r'Context:[^*]*\*?\s*([0-9][0-9A-Z]*)', text)
        free_text = 'FREE' if ('$ 0 ' in text or ('$0' in text) or 'free' in name.lower()) else ''
        web_text = 'WebSearch' if 'Web Search' in text else ''
        rate_text = ''
        if 'limited' in text.lower() or 'resource' in text.lower():
            # Try to extract rate limit phrase
            rate_text = 'RateLimitTextPresent'
        price_part = text
        print(f"=== {count:02d}. {name} | slug:{slug} | {free_text}{rate_text} ===")
        print(price_part[:250])
        print()
