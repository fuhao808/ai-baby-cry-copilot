import os

try:
    from openai import AsyncOpenAI
except ImportError:  # pragma: no cover - handled by runtime fallback
    AsyncOpenAI = None

FALLBACK_ADVICE = {
    "Hungry": (
        "1. Check the time since the last feed.\n"
        "2. Watch for rooting or sucking cues.\n"
        "3. Offer the breast or bottle calmly."
    ),
    "Sleepy": (
        "1. Dim the lights and reduce stimulation.\n"
        "2. Swaddle or hold the baby close.\n"
        "3. Rock gently and lower noise."
    ),
    "Pain/Gas": (
        "1. Burp the baby upright.\n"
        "2. Try slow tummy massage or bicycle legs.\n"
        "3. Check diaper, temperature, and clothing fit."
    ),
    "Fussy": (
        "1. Change the environment and lower noise.\n"
        "2. Offer gentle rocking or skin-to-skin.\n"
        "3. Check diaper, temperature, and comfort."
    ),
}


async def get_soothing_advice(likely_class: str) -> str:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key or AsyncOpenAI is None:
        return FALLBACK_ADVICE.get(likely_class, FALLBACK_ADVICE["Fussy"])

    client = AsyncOpenAI(api_key=api_key)
    model = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

    try:
        response = await client.chat.completions.create(
            model=model,
            temperature=0.3,
            max_tokens=120,
            messages=[
                {
                    "role": "system",
                    "content": "You are a concise infant-care assistant. Reply with only 3 short bullet points.",
                },
                {
                    "role": "user",
                    "content": (
                        f"A baby is crying because they are likely {likely_class}. "
                        "Give 3 short, actionable bullet points for the parents to soothe the baby. "
                        "Keep it under 50 words total."
                    ),
                },
            ],
        )
        content = response.choices[0].message.content
        if content:
            return content.strip()
    except Exception:
        pass

    return FALLBACK_ADVICE.get(likely_class, FALLBACK_ADVICE["Fussy"])
