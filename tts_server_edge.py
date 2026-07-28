"""
🔊 Edge TTS Flask Server สำหรับ LumoRead
ใช้ Microsoft Edge TTS (Neural Voice) - ฟรี + เสียงดีมาก

วิธีติดตั้ง:
    pip install flask flask-cors edge-tts --break-system-packages

วิธีรัน:
    python tts_server.py

Endpoints:
    POST /tts          - แปลงข้อความเป็นเสียง (return MP3 file)
    POST /tts-base64   - แปลงข้อความเป็นเสียง (return base64)
    GET  /voices       - รายการเสียงภาษาไทยทั้งหมด
    GET  /healthz      - Health check
"""

from flask import Flask, request, send_file, jsonify
from flask_cors import CORS
import edge_tts
import asyncio
import os
import base64
import tempfile
import time

app = Flask(__name__)
CORS(app)

# =====================================================
# Thai Voice Options (Microsoft Edge Neural Voices)
# =====================================================
THAI_VOICES = {
    "premwadee": "th-TH-PremwadeeNeural",  # ผู้หญิง (แนะนำ!)
    "niwat": "th-TH-NiwatNeural",          # ผู้ชาย
}

DEFAULT_VOICE = "th-TH-PremwadeeNeural"
DEFAULT_RATE = "+0%"
DEFAULT_PITCH = "+0Hz"

print("✅ Edge TTS พร้อมใช้งาน!")


# =====================================================
# Helper Functions
# =====================================================
async def generate_speech(text: str, voice: str, rate: str, pitch: str, output_path: str):
    """สร้างไฟล์เสียงด้วย Edge TTS"""
    communicate = edge_tts.Communicate(text, voice, rate=rate, pitch=pitch)
    await communicate.save(output_path)


def run_tts(text: str, voice: str = DEFAULT_VOICE, rate: str = DEFAULT_RATE, pitch: str = DEFAULT_PITCH) -> str:
    """Wrapper สำหรับเรียก async function"""
    with tempfile.NamedTemporaryFile(suffix='.mp3', delete=False) as tmp:
        tmp_path = tmp.name
    
    asyncio.run(generate_speech(text, voice, rate, pitch, tmp_path))
    return tmp_path


# =====================================================
# Endpoints
# =====================================================

@app.route('/healthz', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "ok",
        "tts_engine": "Microsoft Edge TTS",
        "default_voice": DEFAULT_VOICE,
        "available_voices": list(THAI_VOICES.keys())
    })


@app.route('/voices', methods=['GET'])
def list_voices():
    """รายการเสียงภาษาไทยทั้งหมด"""
    return jsonify({
        "thai_voices": THAI_VOICES,
        "default": DEFAULT_VOICE
    })


@app.route('/tts', methods=['POST'])
def text_to_speech():
    """
    แปลงข้อความเป็นเสียง (return MP3 file)
    
    Request JSON:
        {
            "text": "สวัสดีครับ",
            "voice": "premwadee",  // optional
            "rate": "-10%",        // optional
            "pitch": "+0Hz"        // optional
        }
    """
    try:
        data = request.get_json() or {}
        text = data.get('text', '')
        
        if not text:
            return jsonify({"error": "No text provided"}), 400
        
        voice_key = data.get('voice', 'premwadee').lower()
        voice = THAI_VOICES.get(voice_key, DEFAULT_VOICE)
        rate = data.get('rate', DEFAULT_RATE)
        pitch = data.get('pitch', DEFAULT_PITCH)
        
        print(f"🎤 TTS: \"{text[:50]}...\" (voice={voice_key})")
        
        start_time = time.time()
        tmp_path = run_tts(text, voice, rate, pitch)
        elapsed = time.time() - start_time
        
        print(f"✅ สร้างเสียงสำเร็จ ({elapsed:.2f}s)")
        
        return send_file(
            tmp_path,
            mimetype='audio/mpeg',
            as_attachment=True,
            download_name='speech.mp3'
        )
        
    except Exception as e:
        print(f"❌ TTS Error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/tts-base64', methods=['POST'])
def text_to_speech_base64():
    """
    แปลงข้อความเป็นเสียง (return base64)
    
    Request JSON:
        {"text": "สวัสดีครับ", "voice": "premwadee"}
    
    Response JSON:
        {"audio": "base64...", "format": "mp3"}
    """
    try:
        data = request.get_json() or {}
        text = data.get('text', '')
        
        if not text:
            return jsonify({"error": "No text provided"}), 400
        
        voice_key = data.get('voice', 'premwadee').lower()
        voice = THAI_VOICES.get(voice_key, DEFAULT_VOICE)
        rate = data.get('rate', DEFAULT_RATE)
        pitch = data.get('pitch', DEFAULT_PITCH)
        
        print(f"🎤 TTS (base64): \"{text[:50]}...\"")
        
        start_time = time.time()
        tmp_path = run_tts(text, voice, rate, pitch)
        elapsed = time.time() - start_time
        
        with open(tmp_path, 'rb') as f:
            audio_bytes = f.read()
        
        audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
        os.unlink(tmp_path)
        
        print(f"✅ สร้างเสียงสำเร็จ ({elapsed:.2f}s, {len(audio_bytes)} bytes)")
        
        return jsonify({
            "audio": audio_base64,
            "format": "mp3",
            "voice": voice_key,
            "processing_time_ms": int(elapsed * 1000)
        })
        
    except Exception as e:
        print(f"❌ TTS Error: {e}")
        return jsonify({"error": str(e)}), 500


# =====================================================
# Main
# =====================================================
if __name__ == '__main__':
    print("""
╔════════════════════════════════════════════════════════╗
║     🔊 Edge TTS Server (Microsoft Neural Voice)       ║
╠════════════════════════════════════════════════════════╣
║  Thai Voices:                                          ║
║    • premwadee - ผู้หญิง (th-TH-PremwadeeNeural) ⭐    ║
║    • niwat     - ผู้ชาย (th-TH-NiwatNeural)           ║
╠════════════════════════════════════════════════════════╣
║  Endpoints:                                            ║
║    POST /tts        → return MP3 file                 ║
║    POST /tts-base64 → return base64 JSON              ║
║    GET  /voices     → list voices                     ║
║    GET  /healthz    → health check                    ║
╚════════════════════════════════════════════════════════╝
    """)
    
    app.run(host='0.0.0.0', port=5001, debug=True)