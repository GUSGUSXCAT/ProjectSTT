"""
🔊🎤 LumoRead STT + TTS Combined Server
✅ CORS Fixed for Flutter Web

วิธีติดตั้ง:
    pip install flask flask-cors edge-tts transformers torch librosa soundfile --break-system-packages

วิธีรัน:
    python stt_tts_server.py
"""

import io, os, tempfile, subprocess, re, sys, time, base64, asyncio
from typing import List
import numpy as np
import soundfile as sf
import torch
import librosa
from flask import Flask, request, jsonify, send_file, make_response
from flask_cors import CORS
from transformers import Wav2Vec2ForCTC, Wav2Vec2Processor
from datetime import datetime
from pythainlp.tokenize import word_tokenize 


try:
    import edge_tts
    TTS_LOADED = True
    print("✅ Edge TTS พร้อมใช้งาน!")
except ImportError:
    TTS_LOADED = False
    print("⚠️ Edge TTS ไม่ได้ติดตั้ง - pip install edge-tts")


MODEL_DIR = "GUSGUSxCAT/EDUPJ2"
BASE_MODEL = "airesearch/wav2vec2-large-xlsr-53-th"
TARGET_SR = 16000
TRIM_TOP_DB = 20
CHUNK_SEC = 15.0
CHUNK_OVERLAP = 2.0

# TTS Configuration
THAI_VOICES = {
    "premwadee": "th-TH-PremwadeeNeural",
    "niwat": "th-TH-NiwatNeural",
}
DEFAULT_VOICE = "th-TH-PremwadeeNeural"
DEFAULT_RATE = "+0%"
DEFAULT_PITCH = "+0Hz"


app = Flask(__name__)

CORS(app, 
     resources={r"/*": {"origins": "*"}},
     allow_headers=["Content-Type", "Authorization", "ngrok-skip-browser-warning"],
     methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
     supports_credentials=False)


@app.after_request
def add_cors_headers(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization, ngrok-skip-browser-warning'
    response.headers['Access-Control-Max-Age'] = '3600'
    return response

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
torch.set_num_threads(max(1, os.cpu_count() or 1))


processor = None
model = None
decoder = None
HAS_CTCDECODER = False
MODEL_LOADED = False

# ================== Model Loading ==================
def load_model():
    global processor, model, decoder, HAS_CTCDECODER, MODEL_LOADED

    if MODEL_LOADED:
        return True

    try:
        print("Loading model...")
        print(f"  📦 Processor: {BASE_MODEL}")
        print(f"  🧠 Model: {MODEL_DIR}")
        
        processor = Wav2Vec2Processor.from_pretrained(BASE_MODEL)
        model = Wav2Vec2ForCTC.from_pretrained(MODEL_DIR).to(device)
        model.eval()

        try:
            from pyctcdecode import build_ctcdecoder
            vocab = processor.tokenizer.get_vocab()
            id2token = [k for k, v in sorted(vocab.items(), key=lambda kv: kv[1])]
            decoder = build_ctcdecoder(id2token, kenlm_model_path=None)
            HAS_CTCDECODER = True
        except Exception:
            decoder = None
            HAS_CTCDECODER = False

        MODEL_LOADED = True
        print("✅ Model loaded successfully")
        return True

    except Exception as e:
        print(f"❌ Failed to load model: {e}")
        import traceback
        traceback.print_exc()
        return False


# ================== Audio Processing ==================
def _read_audio_any(raw_bytes, filename="audio"):
    if not raw_bytes or len(raw_bytes) == 0:
        raise ValueError("Received empty audio bytes")

    try:
        data, sr = sf.read(io.BytesIO(raw_bytes), dtype="float32", always_2d=False)
        return data, sr
    except Exception as e:
        print(f"[Audio] soundfile failed ({e}), trying ffmpeg...")

    ext = os.path.splitext(filename)[1] or ".bin"
    with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as src, \
         tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as dst:
        src.write(raw_bytes)
        src.flush()
        try:
            subprocess.run(
                ["ffmpeg", "-y", "-i", src.name, "-ar", str(TARGET_SR), "-ac", "1", dst.name],
                check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
            data, sr = sf.read(dst.name, dtype="float32", always_2d=False)
        finally:
            try:
                os.remove(src.name)
                os.remove(dst.name)
            except Exception:
                pass
        return data, sr


def _to_mono16k(sig, sr):
    if sig is None or (hasattr(sig, 'size') and sig.size == 0):
        raise ValueError("Audio array is empty before processing")

    if getattr(sig, "ndim", 1) > 1:
        sig = np.mean(sig, axis=1)

    try:
        trimmed, _ = librosa.effects.trim(sig, top_db=TRIM_TOP_DB)
        if trimmed.size > 0:
            sig = trimmed
    except Exception:
        pass

    if sr != TARGET_SR:
        sig = librosa.resample(sig, orig_sr=sr, target_sr=TARGET_SR)
        sr = TARGET_SR

    min_samples = int(0.1 * TARGET_SR)
    if sig.size < min_samples:
        raise ValueError(f"Audio too short: {sig.size} samples.")

    if np.max(np.abs(sig)) < 1e-6:
        raise ValueError("Audio is silent.")

    return sig, sr


def _chunks(sig, sr, chunk_sec=CHUNK_SEC, overlap=CHUNK_OVERLAP):
    if sig.size == 0:
        return
    size = int(chunk_sec * sr)
    step = int(max(0.1, (chunk_sec - overlap)) * sr)
    i = 0
    while i < sig.shape[0]:
        yield sig[i:i+size]
        i += step


def _decode_chunk(x, sr, hotchars=None, hot_weight=8.0):
    if x is None or x.size == 0:
        return ""

    inputs = processor(x, sampling_rate=sr, return_tensors="pt", padding=True)
    inputs = {k: v.to(device) for k, v in inputs.items()}

    with torch.inference_mode():
        logits = model(**inputs).logits

    if HAS_CTCDECODER and decoder:
        try:
            txt = decoder.decode(
                logits[0].detach().cpu().numpy(),
                hotwords=(list(hotchars) if hotchars else []),
                hotword_weight=hot_weight
            )
            txt = (txt or "").strip()
            if txt:
                return txt
        except Exception:
            pass

    pred_ids = torch.argmax(logits, dim=-1)
    return processor.batch_decode(pred_ids, skip_special_tokens=True)[0].strip()



async def _generate_speech(text: str, voice: str, rate: str, pitch: str, output_path: str):
    communicate = edge_tts.Communicate(text, voice, rate=rate, pitch=pitch)
    await communicate.save(output_path)


def _run_tts(text: str, voice: str = DEFAULT_VOICE, rate: str = DEFAULT_RATE, pitch: str = DEFAULT_PITCH) -> str:
    with tempfile.NamedTemporaryFile(suffix='.mp3', delete=False) as tmp:
        tmp_path = tmp.name
    
    asyncio.run(_generate_speech(text, voice, rate, pitch, tmp_path))
    return tmp_path




@app.route('/tts-base64', methods=['POST', 'OPTIONS'])
def text_to_speech_base64():
    """TTS endpoint - return base64 audio"""

    if request.method == 'OPTIONS':
        response = make_response('', 204)
        response.headers['Access-Control-Allow-Origin'] = '*'
        response.headers['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type, ngrok-skip-browser-warning'
        response.headers['Access-Control-Max-Age'] = '3600'
        return response
    
    if not TTS_LOADED:
        return jsonify({"error": "Edge TTS not installed"}), 500
    
    try:
        data = request.get_json() or {}
        text = data.get('text', '')
        
        if not text:
            return jsonify({"error": "No text provided"}), 400
        
        voice_key = data.get('voice', 'premwadee').lower()
        voice = THAI_VOICES.get(voice_key, DEFAULT_VOICE)
        rate = data.get('rate', DEFAULT_RATE)
        pitch = data.get('pitch', DEFAULT_PITCH)
        
        print(f"🔊 TTS: \"{text}\"")
        
        start_time = time.time()
        tmp_path = _run_tts(text, voice, rate, pitch)
        elapsed = time.time() - start_time
        
        with open(tmp_path, 'rb') as f:
            audio_bytes = f.read()
        
        audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
        os.unlink(tmp_path)
        
        print(f"✅ TTS สำเร็จ ({elapsed:.2f}s, {len(audio_bytes)} bytes)")
        
        return jsonify({
            "audio": audio_base64,
            "format": "mp3",
            "voice": voice_key,
            "processing_time_ms": int(elapsed * 1000)
        })
        
    except Exception as e:
        print(f"❌ TTS Error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route('/tts', methods=['POST', 'OPTIONS'])
def text_to_speech():
    """TTS endpoint - return MP3 file"""
    
    if request.method == 'OPTIONS':
        response = make_response('', 204)
        response.headers['Access-Control-Allow-Origin'] = '*'
        response.headers['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type, ngrok-skip-browser-warning'
        return response
    
    if not TTS_LOADED:
        return jsonify({"error": "Edge TTS not installed"}), 500
    
    try:
        data = request.get_json() or {}
        text = data.get('text', '')
        
        if not text:
            return jsonify({"error": "No text provided"}), 400
        
        voice_key = data.get('voice', 'premwadee').lower()
        voice = THAI_VOICES.get(voice_key, DEFAULT_VOICE)
        rate = data.get('rate', DEFAULT_RATE)
        pitch = data.get('pitch', DEFAULT_PITCH)
        
        tmp_path = _run_tts(text, voice, rate, pitch)
        
        return send_file(
            tmp_path,
            mimetype='audio/mpeg',
            as_attachment=True,
            download_name='speech.mp3'
        )
        
    except Exception as e:
        print(f"❌ TTS Error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/voices', methods=['GET', 'OPTIONS'])
def list_voices():
    if request.method == 'OPTIONS':
        return '', 204
    
    return jsonify({
        "thai_voices": THAI_VOICES,
        "default": DEFAULT_VOICE,
        "tts_available": TTS_LOADED
    })


# ================== STT Endpoint ==================
@app.route("/stt", methods=["POST", "OPTIONS"])
def stt():
    if request.method == 'OPTIONS':
        response = make_response('', 204)
        response.headers['Access-Control-Allow-Origin'] = '*'
        response.headers['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type, ngrok-skip-browser-warning'
        return response

    try:
        load_model()
        
        if "audio" not in request.files:
            raise ValueError("No file field 'audio' in request")

        f = request.files["audio"]
        raw = f.read()

        if not raw:
            raise ValueError("Uploaded audio file is empty")

        data, sr = _read_audio_any(raw, filename=f.filename or "audio.wav")
        data, sr = _to_mono16k(data, sr)

        # Transcribe
        hotchars = None
        expected = (request.form.get("expected") or "").strip()
        if expected:
            hotchars = set(list(expected))
        
        parts = []
        for ch in _chunks(data, sr):
            txt = _decode_chunk(ch, sr, hotchars=hotchars, hot_weight=8.0)
            parts.append(txt)
        text = "".join(parts).strip()

        print(f"[STT] Result: '{text}'")
        
        transcript_words = word_tokenize(text, engine='newmm') if text else []
        expected_words = word_tokenize(expected, engine='newmm') if expected else []

        return jsonify({
            "text": text,
            "transcript_words": transcript_words,
            "expected_words": expected_words,
            "timestamp": datetime.now().isoformat()
        })

    except ValueError as e:
        print(f"[STT] Input error: {e}")
        return jsonify({"error": str(e)}), 400

    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ================== Health Check ==================
@app.route("/healthz", methods=["GET", "OPTIONS"])
def healthz():
    if request.method == 'OPTIONS':
        return '', 204

    try:
        load_model()
        return jsonify({
            "status": "ok",
            "device": str(device),
            "stt_loaded": MODEL_LOADED,
            "tts_loaded": TTS_LOADED,
            "model": MODEL_DIR,
        })
    except Exception as e:
        return jsonify({"status": "error", "error": str(e)}), 500


# ================== Home Page ==================
@app.route("/", methods=["GET"])
def home():
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>LumoRead STT + TTS API</title>
        <meta charset="UTF-8">
        <style>
            body { font-family: 'Segoe UI', sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; background: #f5f5f5; }
            .card { background: white; padding: 20px; margin: 20px 0; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            h1 { color: #333; }
            input, button { padding: 12px 20px; font-size: 16px; border-radius: 5px; border: 1px solid #ddd; }
            button { background: #4CAF50; color: white; cursor: pointer; border: none; margin: 5px; }
            button:hover { background: #45a049; }
            #status { margin-top: 10px; padding: 10px; border-radius: 5px; }
            .success { background: #d4edda; color: #155724; }
            .error { background: #f8d7da; color: #721c24; }
            .loading { background: #fff3cd; color: #856404; }
        </style>
    </head>
    <body>
        <h1>🎤🔊 LumoRead STT + TTS API</h1>
        
        <div class="card">
            <h2>📊 Status</h2>
            <p>🎤 STT: <span id="stt-status">Loading...</span></p>
            <p>🔊 TTS: <span id="tts-status">Loading...</span></p>
        </div>
        
        <div class="card">
            <h2>🧪 Test TTS</h2>
            <input type="text" id="text" value="สวัสดีครับ ยินดีต้อนรับ" style="width:100%;">
            <br><br>
            <button onclick="testTTS()">🔊 พูด</button>
            <div id="status"></div>
        </div>
        
        <script>
        fetch('/healthz')
            .then(r => r.json())
            .then(data => {
                document.getElementById('stt-status').innerText = data.stt_loaded ? '✅ Loaded' : '❌ Not loaded';
                document.getElementById('tts-status').innerText = data.tts_loaded ? '✅ Loaded' : '❌ Not loaded';
            });
        
        async function testTTS() {
            const text = document.getElementById('text').value;
            const status = document.getElementById('status');
            
            status.className = 'loading';
            status.innerText = '⏳ กำลังสร้างเสียง...';
            
            try {
                const res = await fetch('/tts-base64', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({text: text, voice: 'premwadee'})
                });
                
                const data = await res.json();
                
                if (data.audio) {
                    status.className = 'success';
                    status.innerText = '✅ สำเร็จ! (' + data.processing_time_ms + 'ms)';
                    
                    const audio = new Audio('data:audio/mp3;base64,' + data.audio);
                    audio.play();
                } else {
                    status.className = 'error';
                    status.innerText = '❌ Error: ' + (data.error || 'Unknown');
                }
            } catch(e) {
                status.className = 'error';
                status.innerText = '❌ Error: ' + e;
            }
        }
        </script>
    </body>
    </html>
    """, 200


# ================== Main ==================
if __name__ == "__main__":
    print("=" * 60)
    print("🎤🔊 LumoRead STT + TTS Server")
    print("✅ CORS Fixed for Flutter Web")
    print("=" * 60)

    if not load_model():
        print("❌ Failed to load STT model.")
        sys.exit(1)

    app.config['MAX_CONTENT_LENGTH'] = 25 * 1024 * 1024
    app.config['JSON_AS_ASCII'] = False

    print(f"\n✅ Server ready!")
    print(f"   STT: {'✅' if MODEL_LOADED else '❌'}")
    print(f"   TTS: {'✅' if TTS_LOADED else '❌'}")
    print("\n📡 http://127.0.0.1:5000")
    print("=" * 60)

    app.run(
        host="0.0.0.0",
        port=5000,
        debug=False,
        threaded=True
    )