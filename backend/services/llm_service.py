import os

try:
    from openai import AsyncOpenAI
except ImportError:  # pragma: no cover - handled by runtime fallback
    AsyncOpenAI = None

CRY_FALLBACK_ADVICE = {
    "Hungry": (
        "This leans hungry because 'neh'-style patterns often show up with rooting-type feeding cues.\n"
        "1. Check the time since the last feed.\n"
        "2. Watch for rooting or sucking cues.\n"
        "3. Offer the breast or bottle calmly."
    ),
    "Sleepy": (
        "This leans sleepy because softer 'owh'-like patterns often show up when babies are winding down.\n"
        "1. Dim the lights and reduce stimulation.\n"
        "2. Swaddle or hold the baby close.\n"
        "3. Rock gently and lower noise."
    ),
    "Pain/Gas": (
        "This leans pain or gas because tighter 'eairh'-type cries often sound strained or abrupt.\n"
        "1. Burp the baby upright.\n"
        "2. Try slow tummy massage or bicycle legs.\n"
        "3. Check diaper, temperature, and clothing fit."
    ),
    "Fussy": (
        "This sounds more fussy or uncomfortable because the pattern is irregular without one strong single cue.\n"
        "1. Change the environment and lower noise.\n"
        "2. Offer gentle rocking or skin-to-skin.\n"
        "3. Check diaper, temperature, and comfort."
    ),
}

SCREENING_FALLBACK_ADVICE = {
    "Adult Voice": (
        "This clip sounds more like adult speech than infant crying.\n"
        "1. Move closer to the baby and reduce adult talking nearby.\n"
        "2. Record again in a quieter space.\n"
        "3. Keep the microphone pointed toward the crib or stroller."
    ),
    "Impact / Knock": (
        "This clip sounds more like tapping or impact noise than a vocal sound.\n"
        "1. Hold the phone steadier and avoid touching the microphone.\n"
        "2. Try another sample with the baby centered in the audio.\n"
        "3. Re-record once the room is still."
    ),
    "Background Noise": (
        "The main signal here sounds like room noise rather than a baby vocalization.\n"
        "1. Lower TV, fan, or room noise if possible.\n"
        "2. Move the phone closer to the baby.\n"
        "3. Try a fresh sample once the main sound is the baby."
    ),
    "Unclear Audio": (
        "No clear infant signal was detected, so the clip was too faint or too mixed.\n"
        "1. Retry in a quieter moment or move closer.\n"
        "2. Keep the microphone aimed at the baby.\n"
        "3. Record a fresh clip once vocalizing starts."
    ),
    "Excited": (
        "Baby voice was detected, but it sounds more excited or stimulated than distressed.\n"
        "1. Watch body language before treating it as a cry event.\n"
        "2. Recheck only if the sound escalates.\n"
        "3. Look for smiles, kicking, or playful movement."
    ),
    "Seeking Attention": (
        "Baby voice was detected, but it sounds more like a call for attention than a distress cry.\n"
        "1. Try eye contact, gentle talk, or picking the baby up.\n"
        "2. Recheck only if the sound escalates into a sustained cry.\n"
        "3. Watch whether the baby settles with contact."
    ),
    "Content/Playful": (
        "Baby voice was detected, but it sounds playful or content rather than upset.\n"
        "1. This may be cooing, babble, or light vocal play.\n"
        "2. No strong distress cue was detected here.\n"
        "3. Keep observing unless the sound becomes sharper or sustained."
    ),
}

async def get_analysis_guidance(
    *,
    top_result: str,
    analysis_family: str,
    screening_label: str,
    detected_sound: str | None = None,
    phonetic_patterns: list[str] | None = None,
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
        detected_sound=detected_sound,
        phonetic_patterns=phonetic_patterns or [],
    )

    try:
        response = await client.chat.completions.create(
            model=model,
            temperature=0.3,
            max_tokens=120,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are a warm, concise infant-care assistant. "
                        "Reply with one short explanatory sentence, then 3 short bullet points."
                    ),
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
        detected_sound=None,
        phonetic_patterns=[],
    )


def _build_prompt(
    *,
    top_result: str,
    analysis_family: str,
    screening_label: str,
    detected_sound: str | None,
    phonetic_patterns: list[str],
) -> str:
    pattern_hint = ""
    if phonetic_patterns:
        pattern_hint = f" The detected vocal cue sounded like {', '.join(phonetic_patterns)}."
    elif detected_sound:
        pattern_hint = f" The detected sound was described as: {detected_sound}."

    if analysis_family == "baby_cry":
        return (
            f"A baby cry was detected and the likely need is {top_result}. "
            f"{pattern_hint} "
            "Start with one short, reassuring sentence that explains why this result was chosen. "
            "Then give 3 short, actionable bullet points for what the parent should try next. "
            "Keep it concise and human."
        )

    return (
        f"The audio screening result is '{screening_label}' with top label '{top_result}'. "
        f"{pattern_hint} "
        "Start with one short sentence explaining what was detected. "
        "Then give 3 short bullet points that explain what the parent should do next. "
        "Focus on retry guidance, environment cleanup, or observing the baby rather than cry-specific soothing. "
        "Keep it concise and human."
    )


def _fallback_guidance(top_result: str, analysis_family: str) -> str:
    if analysis_family == "baby_cry":
        return CRY_FALLBACK_ADVICE.get(top_result, CRY_FALLBACK_ADVICE["Fussy"])

    return SCREENING_FALLBACK_ADVICE.get(
        top_result,
        SCREENING_FALLBACK_ADVICE["Unclear Audio"],
    )
