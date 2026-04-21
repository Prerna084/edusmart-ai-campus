"""
Hybrid Multi-Level Local LLM Fallback System for EduSmart AI Campus.

Fallback Hierarchy (strict priority order):
  0. Online AI   → Google Gemini 1.5 Flash   (primary, cloud)
  1. Fallback 1  → Qwen2.5-7B-Instruct        (main local intelligence layer)
  2. Fallback 2  → Mistral 7B                 (reasoning / logic tasks)
  3. Fallback 3  → Phi-3.5 Mini               (lightweight emergency model)
  4. Fallback 4  → Llama 3.1 8B (quantized)   (final safety fallback)
  5. Static      → Pre-built template          (always available, offline)

Switching is fully automatic and invisible to the user. Every inference is
logged to the `ai_logs` table so admins can audit which model was used.
"""

import os
import time
import json
import asyncio
from typing import Any, Dict, Optional

import httpx
from dotenv import load_dotenv
from sqlalchemy.orm import Session

load_dotenv()

# Try to import the official Google Generative AI SDK (preferred over raw HTTP)
try:
    import google.generativeai as genai
    _GENAI_AVAILABLE = True
except ImportError:
    _GENAI_AVAILABLE = False
    print("⚠️  google-generativeai SDK not installed; falling back to raw httpx for Gemini.")

# ── Configuration ─────────────────────────────────────────────────────────────
GOOGLE_API_KEY: Optional[str] = os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
OLLAMA_BASE_URL: str = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
ONLINE_TIMEOUT: float = float(os.getenv("AI_ONLINE_TIMEOUT", "12"))   # seconds
LOCAL_TIMEOUT: float  = float(os.getenv("AI_LOCAL_TIMEOUT",  "45"))   # seconds

# Model names as served by Ollama (must match `ollama list`)
QWEN_MODEL    = "qwen2.5:7b"
MISTRAL_MODEL = "mistral"
PHI_MODEL     = "phi3.5"
LLAMA_MODEL   = "llama3.1:8b"

# ── Model hierarchy ───────────────────────────────────────────────────────────
_HIERARCHY = [
    {"id": "gemini",   "name": "Gemini 1.5 Flash",       "type": "online", "model": "gemini-1.5-flash"},
    {"id": "qwen",     "name": "Fallback 1: Qwen2.5-7B",  "type": "local",  "model": QWEN_MODEL},
    {"id": "mistral",  "name": "Fallback 2: Mistral 7B",  "type": "local",  "model": MISTRAL_MODEL},
    {"id": "phi",      "name": "Fallback 3: Phi-3.5 Mini","type": "local",  "model": PHI_MODEL},
    {"id": "llama",    "name": "Fallback 4: Llama 3.1 8B","type": "local",  "model": LLAMA_MODEL},
]


class AIService:
    """
    Unified AI service with automatic multi-level fallback.

    Usage:
        result = await AIService.generate(
            db=db,
            feature="ask_tutor",
            prompt="Explain Binary Search",
            system="You are a helpful tutor."
        )

    Returns a dict:
        {
          "response": "<text>",
          "model":    "<model name>",
          "is_online": True/False,
          "latency_ms": 234
        }
    Or on total failure:
        {
          "error": "All AI models unavailable.",
          "last_error": "<last exception>",
          "status": "offline"
        }
    """

    @staticmethod
    async def generate(
        db: Session,
        feature: str,
        prompt: str,
        system: str = "You are a helpful educational AI assistant.",
        max_tokens: int = 1024,
        temperature: float = 0.7,
    ) -> Dict[str, Any]:
        start = time.time()
        last_error: str = "No models tried."

        for level in _HIERARCHY:
            model_name = level["name"]
            try:
                if level["type"] == "online":
                    text = await AIService._call_gemini(
                        prompt, system, max_tokens, temperature
                    )
                else:
                    text = await AIService._call_ollama(
                        level["model"], prompt, system, max_tokens, temperature
                    )

                if text:
                    latency = int((time.time() - start) * 1000)
                    print(f"✅ [{feature}] served by {model_name} in {latency}ms")
                    AIService._log(db, feature, prompt, text, model_name,
                                   level["type"] == "online", latency)
                    return {
                        "response":   text,
                        "model":      model_name,
                        "is_online":  level["type"] == "online",
                        "latency_ms": latency,
                    }

            except Exception as exc:
                last_error = str(exc)
                print(f"⚠️  [{feature}] {model_name} failed: {last_error[:120]}")
                continue   # try next level

        # All cloud/local levels exhausted — use static template as last resort
        latency = int((time.time() - start) * 1000)
        print(f"⚠️  [{feature}] All AI models unavailable after {latency}ms — using static fallback")
        static = AIService._static_fallback(feature, prompt)
        if static:
            AIService._log(db, feature, prompt, static, "Static Template", False, latency)
            return {
                "response":   static,
                "model":      "Static Template (AI unavailable)",
                "is_online":  False,
                "latency_ms": latency,
            }
        # No static fallback for this feature — surface error clearly
        return {
            "error":      "All AI models are currently unavailable. Please set GOOGLE_API_KEY in the server environment.",
            "last_error": last_error,
            "status":     "offline",
        }

    @staticmethod
    def _static_fallback(feature: str, prompt: str) -> Optional[str]:
        """
        Returns a hardcoded-but-useful JSON string for known features when
        every AI tier is exhausted.  Returns None for unknown features.
        """
        if feature == "study_plan":
            # Extract subject name from prompt if possible
            import re
            m = re.search(r"subject '(.+?)'", prompt)
            subject = m.group(1) if m else "the Subject"
            plan = [
                {
                    "week": 1,
                    "title": f"Week 1: Foundations of {subject}",
                    "topics": [
                        "Introduction and course overview",
                        "Core concepts and terminology",
                        "Historical context and motivation",
                    ],
                    "objective": f"Build a solid foundation for {subject} by understanding its scope, key terminology, and real-world significance.",
                },
                {
                    "week": 2,
                    "title": f"Week 2: Core Principles of {subject}",
                    "topics": [
                        "Fundamental theories and models",
                        "Problem-solving techniques",
                        "Worked examples and case studies",
                    ],
                    "objective": f"Apply the fundamental principles of {subject} to solve structured problems with growing confidence.",
                },
                {
                    "week": 3,
                    "title": f"Week 3: Advanced Topics & Revision",
                    "topics": [
                        "Advanced applications",
                        "Common pitfalls and best practices",
                        "End-of-unit review and mock test",
                    ],
                    "objective": f"Consolidate understanding of {subject}, tackle advanced problems, and prepare for assessment.",
                },
            ]
            return json.dumps(plan)

        if feature == "mcq_gen":
            fallback_mcqs = [
                {
                    "question": "Which of the following best describes the primary goal of this subject?",
                    "options": [
                        "To memorize definitions",
                        "To understand and apply core concepts",
                        "To read textbooks only",
                        "To avoid practical work",
                    ],
                    "correct_index": 1,
                },
                {
                    "question": "A structured problem-solving approach typically starts with:",
                    "options": ["Writing code immediately", "Defining the problem clearly", "Guessing the answer", "Skipping to the solution"],
                    "correct_index": 1,
                },
            ]
            return json.dumps(fallback_mcqs)

        return None  # No static fallback for this feature

    # ── Internal helpers ──────────────────────────────────────────────────────

    @staticmethod
    async def _call_gemini(
        prompt: str, system: str, max_tokens: int, temperature: float
    ) -> str:
        if not GOOGLE_API_KEY:
            raise RuntimeError("GOOGLE_API_KEY / GEMINI_API_KEY not configured")

        # Prefer official SDK when available — better error messages & retry logic
        if _GENAI_AVAILABLE:
            return await AIService._call_gemini_sdk(prompt, system, max_tokens, temperature)
        return await AIService._call_gemini_http(prompt, system, max_tokens, temperature)

    @staticmethod
    async def _call_gemini_sdk(
        prompt: str, system: str, max_tokens: int, temperature: float
    ) -> str:
        """Call Gemini via the official google-generativeai SDK (async wrapper)."""
        genai.configure(api_key=GOOGLE_API_KEY)
        model = genai.GenerativeModel(
            model_name="gemini-1.5-flash",
            system_instruction=system,
            generation_config=genai.types.GenerationConfig(
                max_output_tokens=max_tokens,
                temperature=temperature,
            ),
        )
        # Run synchronous SDK call in a thread so we don't block the event loop
        loop = asyncio.get_event_loop()
        response = await loop.run_in_executor(None, lambda: model.generate_content(prompt))
        return response.text

    @staticmethod
    async def _call_gemini_http(
        prompt: str, system: str, max_tokens: int, temperature: float
    ) -> str:
        """Fallback: call Gemini via raw HTTP when SDK is not installed."""
        url = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            f"gemini-1.5-flash:generateContent?key={GOOGLE_API_KEY}"
        )
        payload = {
            "contents": [
                {"parts": [{"text": f"System: {system}\n\nUser: {prompt}"}]}
            ],
            "generationConfig": {
                "maxOutputTokens": max_tokens,
                "temperature": temperature,
            },
        }
        async with httpx.AsyncClient(timeout=ONLINE_TIMEOUT) as client:
            resp = await client.post(url, json=payload)
            resp.raise_for_status()
            data = resp.json()
            return data["candidates"][0]["content"]["parts"][0]["text"]

    @staticmethod
    async def _call_ollama(
        model: str, prompt: str, system: str, max_tokens: int, temperature: float
    ) -> str:
        url = f"{OLLAMA_BASE_URL}/api/generate"
        payload = {
            "model":  model,
            "prompt": f"{system}\n\nUser: {prompt}\n\nAssistant:",
            "stream": False,
            "options": {
                "num_predict": max_tokens,
                "temperature": temperature,
            },
        }
        async with httpx.AsyncClient(timeout=LOCAL_TIMEOUT) as client:
            resp = await client.post(url, json=payload)
            resp.raise_for_status()
            return resp.json()["response"]

    @staticmethod
    def _log(
        db: Session,
        feature: str,
        prompt: str,
        response: str,
        model_used: str,
        is_online: bool,
        latency_ms: int,
    ) -> None:
        """Non-blocking DB write; silently absorbs errors."""
        try:
            from app.models import AILog  # local import to avoid circular deps
            log = AILog(
                feature=feature,
                prompt=prompt[:1000],
                response=response[:2000],
                model_used=model_used,
                is_online=1 if is_online else 0,
                latency_ms=latency_ms,
            )
            db.add(log)
            db.commit()
        except Exception as e:
            print(f"⚠️  AI log write failed (non-fatal): {e}")


# ── Prompt builders ───────────────────────────────────────────────────────────

def build_mcq_prompt(topic: str, num_questions: int, difficulty: str) -> str:
    return (
        f"Generate exactly {num_questions} multiple choice questions (MCQs) "
        f"on the topic: '{topic}' at difficulty level: '{difficulty}'.\n\n"
        "Return ONLY a valid JSON array (no markdown, no explanation). "
        "Each element must have exactly these keys:\n"
        '  "question": string,\n'
        '  "options": array of exactly 4 strings,\n'
        '  "correct_index": integer 0-3\n\n'
        "Example:\n"
        '[\n  {"question": "What is X?", "options": ["A","B","C","D"], "correct_index": 2}\n]'
    )


def build_study_plan_prompt(subject_title: str, semester: str, batch: str) -> str:
    return (
        f"Create a 3-week study plan for the subject '{subject_title}' "
        f"(Semester {semester}, Batch {batch}).\n\n"
        "Return ONLY a valid JSON array of exactly 3 objects. "
        "Each object must have:\n"
        '  "week": integer (1-3),\n'
        '  "title": string (e.g. "Week 1: Introduction"),\n'
        '  "topics": array of 3-5 strings,\n'
        '  "objective": string\n\n'
        "No markdown. No explanation. Just the JSON array."
    )


def build_tutor_system() -> str:
    return (
        "You are 'EduSmart AI Tutor', a knowledgeable and encouraging academic assistant. "
        "Keep answers clear, structured, and student-friendly. "
        "When explaining code, use the language the student mentioned. "
        "When the student is confused, break concepts into numbered steps."
    )


def extract_json_array(text: str):
    """
    Extracts the first JSON array found in `text`.
    Returns the parsed list, or raises ValueError if not found.
    """
    import re
    m = re.search(r"\[.*?\]", text, re.DOTALL)
    if not m:
        raise ValueError("No JSON array found in AI response")
    return json.loads(m.group(0))
