with open(r'C:\Users\user\.local\share\opencode\tool-output\tool_024cc7196001EdQguHRKMbPhXO', 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

# Replace special unicode chars that break encoding
content = content.replace('\u2011', '-')  # non-breaking hyphen
content = content.replace('\u201c', '"')
content = content.replace('\u201d', '"')
content = content.replace('\u2192', '->')
content = content.replace('\ufffd', '?')

import re
print("Content length after fix:", len(content))

# Find all cards by looking for the model name links followed by pricing info
# Each card is separated by image tags
cards_text = re.split(r'(?=\!\[icon\]\()', content)
print("Split cards:", len(cards_text))

# For each card, try to find pricing
results = []
for card in cards_text:
    if 'Copy ID' not in card and 'Input:' not in card:
        continue
    # Find model name - the last [Name](/model/...) before Copy ID or Input
    links = re.findall(r'\[([^\]]+)\]\(/model/[^)]+\)', card)
    if not links:
        # Try to find from earlier in the card
        continue
    # Get the last link before pricing info
    name = links[-1] if links else "Unknown"
    # Find slug from last link
    slug_match = re.search(r'/model/([^)]+)', card)
    slug = slug_match.group(1) if slug_match else ""

    # Extract input/output prices
    input_text = ""
    output_text = ""
    context_text = ""
    rate_text = ""

    # Look for the price block - find all text between "Input:" and next big break
    input_pos = card.find('Input:')
    if input_pos > -1:
        price_block = card[input_pos:input_pos+500]
        price_block = price_block.split('![icon]')[0]  # stop at next image
        price_block = price_block.replace('<', '').replace('>', '').replace('**', '').strip()
        price_block = ' '.join(price_block.split())

        # Try to extract input price
        inp = re.search(r'Input:[^$]*\$?\s*([0-9.]+)\s*/M', price_block)
        if inp:
            input_text = inp.group(1) + "/M"
        # Sometimes input is $ 0 /M
        if not inp:
            inp0 = re.search(r'Input:[^$]*\$\s*0\s*/M', price_block)
            if inp0:
                input_text = "0/M"

        # Output price
        out = re.search(r'Output:[^$]*\$?\s*([0-9.]+)\s*/M', price_block)
        if out:
            output_text = out.group(1) + "/M"
        if not out:
            out0 = re.search(r'Output:[^$]*\$\s*0\s*/M', price_block)
            if out0:
                output_text = "0/M"

        # Context
        ctx = re.search(r'Context:[^*]*\*?\s*([0-9]+[KM]?)', price_block)
        if ctx:
            context_text = ctx.group(1)

        # Rate limits / special notes
        if 'free' in card.lower() or 'free' in price_block.lower():
            rate_text += "FreeTier;"
        # Look for specific rate limit phrases in the card
        card_lower = card.lower()
        if 'limited' in card_lower:
            rate_text += "LimitedResources;"
        if 'free model resources are limited' in card_lower:
            rate_text += "FreeModelResourcesLimited;"
        if 'unlimited concurrency' in card_lower:
            rate_text += "UnlimitedConcurrency;"
        if '10% off' in card_lower or 'up to' in card_lower and '%' in card_lower:
            rate_text += "Discounted;"

        # Clean name - remove image references
        clean_name = re.sub(r'\(free\)', '', name, flags=re.IGNORECASE).strip()

        # Skip non-text/chat models (image generation, embeddings, OCR, etc.)
        # We include only LLM chat/text models
        skip_indicators = ['embedding', 'ocr', 'rerank', 'vision-exp', 'vision', 'image', 'speech', 'audio', 'video', 'transcription', 'reranker', 'embedding', 'dots 3 note', 'seedance', 'flux', 'meituan', 'stable diffusion', 'hun']
        skip_name = any(ind in clean_name.lower() for ind in skip_indicators)
        # Don't skip vision models that are chat-capable - only pure image/video/audio
        if any(ind in clean_name.lower() for ind in ['embedding', 'ocr', 'rerank', 'seedance', 'flux', 'meituan', 'stable diffusion', 'video', 'audio', 'transcription']):
            skip_name = True

        if not skip_name:
            free_flag = "Paid" if input_text != "0/M" and input_text != "" else ("Free" if 'FREE' in rate_text or input_text == "0/M" else "?")
            if input_text == "0/M":
                free_flag = "Free"
            results.append({
                "name": clean_name,
                "slug": slug,
                "input": input_text,
                "output": output_text,
                "context": context_text,
                "free": free_flag,
                "rate_limit": rate_text,
                "price_block": price_block[:120] if price_block else ""
            })

# Deduplicate by slug
seen_slugs = {}
for r in results:
    slug = r['slug']
    if slug not in seen_slugs:
        seen_slugs[slug] = r

print(f"\n=== EXTRACTED {len(seen_slugs)} UNIQUE MODEL CARDS ===\n")
for slug, r in sorted(seen_slugs.items(), key=lambda x: (x[1]['free'] == 'Paid', x[1]['name'])):
    print(f"SLUG:{slug} NAME:{r['name']} IN:{r['input']} OUT:{r['output']} CTX:{r['context']} FREE:{r['free']} NOTES:{r['rate_limit']} BLOCK:{r['price_block'][:100]}")
