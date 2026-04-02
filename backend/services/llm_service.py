import os

try:
    from openai import AsyncOpenAI
except ImportError:  # pragma: no cover - handled by runtime fallback
    AsyncOpenAI = None

CRY_FALLBACK_ADVICE = {
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

SCREENING_FALLBACK_ADVICE = {
    "Adult Voice": (
        "1. Move closer to the baby and reduce adult talking nearby.\n"
        "2. Record again in a quieter space.\n"
        "3. Keep the microphone pointed toward the crib or stroller."
    ),
    "Impact / Knock": (
        "1. The clip sounds like tapping or impact noise.\n"
        "2. Hold the phone steadier and avoid touching the microphone.\n"
        "3. Try another sample with the baby centered in the audio."
    ),
    "Background Noise": (
        "1. Lower TV, fan, or room noise if possible.\n"
        "2. Move the phone closer to the baby.\n"
        "3. Try a fresh sample once the main sound is the baby."
    ),
    "Unclear Audio": (
        "1. No clear infant signal was detected.\n"
        "2. Retry in a quieter moment or move closer.\n"
        "3. Record for the full 7 seconds if the baby starts vocalizing."
    ),
    "Excited": (
        "1. Baby voice was detected, but it did not sound like crying.\n"
        "2. This clip sounds more excited or stimulated than distressed.\n"
        "3. Watch body language before treating it as a cry event."
    ),
    "Seeking Attention": (
        "1. Baby voice was detected, but it did not sound like a cry.\n"
        "2. Try eye contact, gentle talk, or picking the baby up.\n"
        "3. Recheck only if the sound escalates into a sustained cry."
    ),
    "Content/Playful": (
        "1. Baby voice was detected, but it sounds playful or content.\n"
        "2. This may be cooing, babble, or light vocal play.\n"
        "3. No distress cue was strongly detected in this clip."
    ),
}

async def get_analysis_guidance(
    *,
    top_result: str,
    analysis_family: str,
    screening_label: str,
) -> str:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key or AsyncOpenAI is None:
        return _fallback_guidance(top_result, analysis_family)

    client = AsyncOpenAI(api_key=api_key)
    model = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
    user_prompt = _build_prompt(
        top_result=top_result,
        analysis_family=analysis_family,
        screening_label=screening_label,
    )

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
                    "content": user_prompt,
                },
            ],
        )
        content = response.choices[0].message.content
        if content:
            return content.strip()
    except Exception:
        pass

    return _fallback_guidance(top_result, analysis_family)


async def get_soothing_advice(likely_class: str) -> str:
    return await get_analysis_guidance(
        top_result=likely_class,
        analysis_family="baby_cry",
        screening_label="Baby cry detected",
    )


def _build_prompt(
    *,
    top_result: str,
    analysis_family: str,
    screening_label: str,
) -> str:
    if analysis_family == "baby_cry":
        return (
            f"A baby cry was detected and the likely need is {top_result}. "
            "Give 3 short, actionable bullet points for the parents to soothe the baby. "
            "Keep it under 50 words total."
        )

    return (
        f"The audio screening result is '{screening_label}' with top label '{top_result}'. "
        "Give 3 short bullet points that explain what was detected and what the parent should do next. "
        "Focus on retry guidance, environment cleanup, or observing the baby rather than cry-specific soothing. "
        "Keep it under 50 words total."
    )


def _fallback_guidance(top_result: str, analysis_family: str) -> str:
    if analysis_family == "baby_cry":
        return CRY_FALLBACK_ADVICE.get(top_result, CRY_FALLBACK_ADVICE["Fussy"])

    return SCREENING_FALLBACK_ADVICE.get(
        top_result,
        SCREENING_FALLBACK_ADVICE["Unclear Audio"],
    )
