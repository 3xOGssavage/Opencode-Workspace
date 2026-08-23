# Final structured summary of AIHubMix LLM models from tool output file
models_paid = [
    {"name": "GLM 5.3", "slug": "glm-5.3", "in": "1.1268 / 1.01412", "out": "3.9438 / 3.54942", "ctx": "1M", "free": "Paid", "notes": "10% off 00:00-23:59 UTC; unlimited concurrency"},
    {"name": "Coding GLM 5.3", "slug": "coding-glm-5.3", "in": "0.06", "out": "0.22", "ctx": "-", "free": "Paid", "notes": "Limited-time preview version"},
    {"name": "GLM 5.2", "slug": "glm-5.2", "in": "1.1268", "out": "3.9438", "ctx": "1M", "free": "Paid", "notes": "Unlimited concurrency; production-ready"},
    {"name": "GPT 5.6 Sol Disc", "slug": "gpt-5.6-sol-disc", "in": "5 / 2.5", "out": "30 / 15", "ctx": "-", "free": "Paid", "notes": "Limited-time 50% off 00:00-23:59 UTC; Web Search $0.01/request"},
    {"name": "GPT 5.6 Sol", "slug": "gpt-5.6-sol", "in": "5", "out": "30", "ctx": "-", "free": "Paid", "notes": "Web Search $0.01/request"},
    {"name": "GPT 5.6 Luna", "slug": "gpt-5.6-luna", "in": "0.2", "out": "1.2", "ctx": "-", "free": "Paid", "notes": "Web Search $0.01/request"},
    {"name": "GPT 5.6 Terra", "slug": "gpt-5.6-terra", "in": "2", "out": "12", "ctx": "-", "free": "Paid", "notes": "Web Search $0.01/request"},
    {"name": "DeepSeek V4 Flash 0731", "slug": "deepseek-v4-flash-0731", "in": "0.142", "out": "0.284", "ctx": "1M", "free": "Paid", "notes": "Throughput 165 tok/s; TTFT 1.011s"},
    {"name": "DeepSeek V4 Flash 0731 Fast", "slug": "deepseek-v4-flash-0731-fast", "in": "0.28", "out": "0.56", "ctx": "1M", "free": "Paid", "notes": "Fast version; TTFT 2.952s"},
    {"name": "DeepSeek V4 Pro 0813", "slug": "deepseek-v4-pro-0813", "in": "0.6918", "out": "2.0754", "ctx": "1M", "free": "Paid", "notes": "Throughput 55 tok/s; TTFT 1.682s"},
    {"name": "Grok 4.6", "slug": "grok-4.6", "in": "2", "out": "6", "ctx": "-", "free": "Paid", "notes": "xAI flagship multimodal reasoning model"},
    {"name": "Mai Thinking 1", "slug": "mai-thinking-1", "in": "2", "out": "8", "ctx": "256K", "free": "Paid", "notes": "Microsoft AI; TTFT 6.669s; 42 tok/s"},
    {"name": "Agnes 2.5 Flash", "slug": "agnes-2.5-flash", "in": "0.03", "out": "0.15", "ctx": "512K", "free": "Paid", "notes": "TTFT 4.318s; Throughput 31 tok/s"},
]

models_free = [
    {"name": "Gemini 3.7 Flash (free)", "slug": "gemini-3.7-flash-free", "in": "0", "out": "0", "ctx": "512K (implied)", "free": "Free", "notes": "Free tier resources limited; not guaranteed stable (may see 429); choose official gemini-3.7-flash for production/unlimited concurrency; Web Search $0.014/request; Cache Storage $1/h/M tokens"},
    {"name": "Ox Alpha (free tier)", "slug": "ox-alpha", "in": "0", "out": "0", "ctx": "-", "free": "Free", "notes": "Free tier resources limited; Web Search $0.014/request"},
    {"name": "Dots 3 Note Preview (free)", "slug": "dots-3-note-preview-free", "in": "0", "out": "0", "ctx": "512K", "free": "Free", "notes": "Preview version with 512K context; 0 price"},
]

general_rules = [
    "GLM-5.3: 10% discount applies daily 00:00-23:59 UTC.",
    "GPT-5.6 Sol Disc: 50% limited-time discount applies daily 00:00-23:59 UTC.",
    "Web Search feature (where supported): $0.01/request for GPT-5.6 series; $0.014/request for Gemini series; $0.00056/request for DeepSeek Vision Exp.",
    "Free model resources are limited and provided only for trial use; stability cannot be guaranteed; users may encounter 429 errors during use.",
    "For production with unlimited concurrency and absolute stability, choose the official (paid) version of the corresponding model (e.g., gemini-3.7-flash for the free preview).",
]

print("AIHubMix LLM Chat Models - Structured Summary")
print("=" * 115)
print(f"{'Name':30s} | {'Copy ID (slug)':28s} | {'In ($/M)':12s} | {'Out ($/M)':12s} | {'Ctx':8s} | {'Free?':6s}")
print("-" * 115)
for m in models_paid:
    in_price = m['in']
    print(f"{m['name']:30s} | {m['slug']:28s} | {in_price:12s} | {m['out']:12s} | {m['ctx']:8s} | {m['free']:6s}")

print()
print("FREE TIER MODELS")
print("-" * 115)
for m in models_free:
    print(f"{m['name']:30s} | {m['slug']:28s} | {m['in']:12s} | {m['out']:12s} | {m['ctx']:8s} | {m['free']:6s}")

print()
print("GENERAL PRICING RULES (applies to all listed above)")
print("-" * 70)
for r in general_rules:
    print("  - " + r)

print()
print("RATE-LIMIT / FREE TIER NOTES (extracted from page)")
print("-" * 70)
print("  - 'Free model resources are limited and provided only for trial use; stability cannot be")
print("     guaranteed, and you may encounter 429 errors during use. If you need to use it in a")
print("     production environment and require unlimited concurrency with absolute stability,")
print("     please choose the official version: gemini-3.7-flash'")
print("  - Discount windows: daily 00:00-23:59 UTC for discounted models.")
print("  - Routing model (auto): charged at actual routed model price; routing free.")
