import os, cv2, torch, uuid, json, sqlite3, numpy as np, faiss
import datetime, hashlib, bcrypt, pickle, base64, secrets, smtplib
import requests, time
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from cryptography.fernet import Fernet
from fastapi import FastAPI, UploadFile, File, HTTPException, Depends, Query
from fastapi.staticfiles import StaticFiles
from fastapi.security import APIKeyHeader
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
from rembg import remove
from PIL import Image
from transformers import CLIPProcessor, CLIPModel
from google import genai
from google.genai import types
import PIL.PngImagePlugin
import PIL.JpegImagePlugin
import io
from dotenv import load_dotenv

load_dotenv()

os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"

DB_FILE     = "smart_shopper.db"
STORAGE_DIR = "storage"
FAISS_FILE  = "faiss_index.bin"
VECMAP_FILE = "vector_map.pkl"
os.makedirs(STORAGE_DIR, exist_ok=True)

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
SERPAPI_KEY    = os.getenv("SERPAPI_KEY",    "")
IMGBB_KEY      = os.getenv("IMGBB_KEY",      "")
SMTP_HOST      = os.getenv("SMTP_HOST",      "smtp.gmail.com")
SMTP_PORT      = int(os.getenv("SMTP_PORT",  "587"))
SMTP_USER      = os.getenv("SMTP_USER",      "")
SMTP_PASS      = os.getenv("SMTP_PASS",      "")

_raw_key   = os.getenv("DB_SECRET_KEY", "")
FERNET_KEY = (base64.urlsafe_b64encode(_raw_key.encode().ljust(32)[:32])
              if _raw_key else Fernet.generate_key())
cipher = Fernet(FERNET_KEY)

def enc(text: str) -> str:
    if not text: return ""
    return cipher.encrypt(text.encode()).decode()

def dec(token: str) -> str:
    try:
        return cipher.decrypt(token.encode()).decode()
    except Exception:
        return token

api_key_header = APIKeyHeader(name="Authorization", auto_error=False)

# ── Timer helper ───────────────────────────────────────────────────────────────
class Timer:
    """مؤقت يظهر بالتيرمنال فقط"""
    def __init__(self, label: str):
        self.label = label
        self.start = None

    def __enter__(self):
        self.start = time.perf_counter()
        print(f"⏱  [{self.label}] بدأ...")
        return self

    def __exit__(self, *_):
        elapsed = time.perf_counter() - self.start
        print(f"✅  [{self.label}] انتهى في {elapsed:.2f}s")

    @property
    def elapsed(self):
        return time.perf_counter() - self.start if self.start else 0.0


# ── Region context — بدون تحديد أسواق، فقط عملة واسم المنطقة ────────────────
REGION_CONTEXT = {
    "SA": {"name": "Saudi Arabia",  "currency": "SAR", "locale": "ar-SA"},
    "AE": {"name": "UAE",           "currency": "AED", "locale": "ar-AE"},
    "KW": {"name": "Kuwait",        "currency": "KWD", "locale": "ar-KW"},
    "QA": {"name": "Qatar",         "currency": "QAR", "locale": "ar-QA"},
    "EG": {"name": "Egypt",         "currency": "EGP", "locale": "ar-EG"},
    "US": {"name": "USA",           "currency": "USD", "locale": "en-US"},
    "GB": {"name": "UK",            "currency": "GBP", "locale": "en-GB"},
    "DE": {"name": "Germany",       "currency": "EUR", "locale": "de-DE"},
    "FR": {"name": "France",        "currency": "EUR", "locale": "fr-FR"},
    "CN": {"name": "China",         "currency": "CNY", "locale": "zh-CN"},
    "ES": {"name": "Spain",         "currency": "EUR", "locale": "es-ES"},
    "TR": {"name": "Turkey",        "currency": "TRY", "locale": "tr-TR"},
    "IN": {"name": "India",         "currency": "INR", "locale": "en-IN"},
    "JP": {"name": "Japan",         "currency": "JPY", "locale": "ja-JP"},
}

app = FastAPI(title="Smart Shopper API v15", version="15.0",
              swagger_ui_parameters={"persistAuthorization": True})

app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
app.mount("/storage", StaticFiles(directory=STORAGE_DIR), name="storage")

def init_db():
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS users (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        email        TEXT UNIQUE NOT NULL,
        first_name   TEXT,
        last_name    TEXT,
        region       TEXT DEFAULT 'SA',
        password     TEXT NOT NULL,
        role         TEXT DEFAULT 'user',
        is_verified  INTEGER DEFAULT 0,
        created_at   TEXT
    )''')
    c.execute('''CREATE TABLE IF NOT EXISTS otps (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        email      TEXT NOT NULL,
        code       TEXT NOT NULL,
        expires_at TEXT NOT NULL
    )''')
    c.execute('''CREATE TABLE IF NOT EXISTS products (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     INTEGER NOT NULL,
        name_enc    TEXT,
        brand_enc   TEXT,
        price       REAL,
        currency    TEXT DEFAULT 'SAR',
        sources     TEXT,
        description TEXT,
        category    TEXT,
        confidence  TEXT,
        image_url   TEXT,
        timestamp   TEXT,
        language    TEXT DEFAULT 'ar',
        region      TEXT DEFAULT 'SA',
        faiss_index INTEGER,
        FOREIGN KEY(user_id) REFERENCES users(id)
    )''')
    conn.commit(); conn.close()

init_db()

CLIP_DIM = 512

def load_faiss():
    if os.path.exists(FAISS_FILE) and os.path.exists(VECMAP_FILE):
        index = faiss.read_index(FAISS_FILE)
        with open(VECMAP_FILE, "rb") as f: vmap = pickle.load(f)
    else:
        index = faiss.IndexFlatIP(CLIP_DIM); vmap = []
    return index, vmap

def save_faiss(index, vmap):
    faiss.write_index(index, FAISS_FILE)
    with open(VECMAP_FILE, "wb") as f: pickle.dump(vmap, f)

faiss_index, vector_map = load_faiss()

gemini_client = genai.Client(api_key=GEMINI_API_KEY)

print("⏳ Loading CLIP…")
clip_model     = CLIPModel.from_pretrained("openai/clip-vit-base-patch32")
clip_processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")
clip_model.eval()
print("✅ CLIP ready")


class Vision:

    @staticmethod
    def segment_product(img):
        try:
            pil = Image.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
            out = remove(pil)
            bbox = out.getbbox()
            if bbox:
                r = cv2.cvtColor(np.array(out.crop(bbox)), cv2.COLOR_RGBA2BGR)
                if r is not None and r.size > 0:
                    return r
        except Exception as e:
            print(f"⚠️ rembg: {e}")
        return img

    @staticmethod
    def _clip_embed(pil_img):
        inputs = clip_processor(images=pil_img, return_tensors="pt")
        with torch.no_grad():
            feat = clip_model.get_image_features(**inputs)
        vec = feat.squeeze().numpy().astype(np.float32)
        faiss.normalize_L2(vec.reshape(1, -1))
        return vec

    @staticmethod
    def extract_robust_vector(img_bgr):
        rgb  = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
        pil  = Image.fromarray(rgb)
        augs = [pil] + [pil.rotate(a, expand=True) for a in (90, 180, 270)] \
               + [pil.transpose(Image.FLIP_LEFT_RIGHT)]
        vecs = np.stack([Vision._clip_embed(a) for a in augs])
        mean = vecs.mean(axis=0).astype(np.float32)
        faiss.normalize_L2(mean.reshape(1, -1))
        return mean

    @staticmethod
    def search_similar(vec, top_k=10, threshold=0.82):
        """
        يبحث عن أقرب منتج في الكاش بغض النظر عن اللغة.
        يرجع المنتج المطابق + نسبة التشابه.
        """
        if faiss_index.ntotal == 0:
            return None
        D, I = faiss_index.search(vec.reshape(1, -1), min(top_k, faiss_index.ntotal))
        conn = sqlite3.connect(DB_FILE); conn.row_factory = sqlite3.Row; c = conn.cursor()
        result = None; similarity = 0.0
        for dist, idx in zip(D[0], I[0]):
            if idx == -1 or float(dist) < threshold:
                continue
            pid = vector_map[idx]
            if pid == -1:
                continue
            c.execute("SELECT * FROM products WHERE id=?", (pid,))
            row = c.fetchone()
            if row:
                result = dict(row); similarity = round(float(dist), 4)
                result["name"]  = dec(result.pop("name_enc",  "") or "")
                result["brand"] = dec(result.pop("brand_enc", "") or "")
                break
        conn.close()
        return {"product": result, "similarity": similarity} if result else None

    @staticmethod
    def save_faiss(index, vmap):
        save_faiss(index, vmap)


class LiveSearch:

    @staticmethod
    def get_live_visual_data(img_array, region_code: str) -> str:
        """
        يبحث بصريًا عبر Google Lens ويرجع نتائج من الويب العام
        بدون تقييد لأسواق معينة.
        """
        if not SERPAPI_KEY or not IMGBB_KEY:
            return "[]"
        try:
            _, buf = cv2.imencode('.jpg', img_array)
            res    = requests.post(
                "https://api.imgbb.com/1/upload",
                data={"key": IMGBB_KEY},
                files={"image": buf.tobytes()},
                timeout=15
            )
            url = res.json().get("data", {}).get("url")
            if not url:
                return "[]"

            region_info = REGION_CONTEXT.get(region_code, REGION_CONTEXT["SA"])

            # بحث Lens بالريجون الصحيح
            lens = requests.get("https://serpapi.com/search", timeout=20, params={
                "engine": "google_lens",
                "url": url,
                "gl": region_code.lower(),   # بلد المستخدم
                "hl": region_info["locale"].split("-")[0],  # لغة المستخدم
                "api_key": SERPAPI_KEY
            })
            out = []
            for item in lens.json().get("visual_matches", [])[:6]:
                if item.get("title"):
                    out.append({
                        "title":  item["title"],
                        "price":  item.get("price", {}).get("extracted_value", "N/A"),
                        "source": item.get("source", ""),
                        "link":   item.get("link", ""),
                    })
            return json.dumps(out, ensure_ascii=False)
        except Exception as e:
            print(f"⚠️ LiveSearch: {e}")
            return "[]"


class LLM:

    # نماذج بديلة للـ fallback
    MODELS = [
        "gemini-2.5-flash-lite",
        "gemini-2.0-flash",
        "gemini-1.5-flash",
    ]

    @staticmethod
    def _call_gemini(model: str, prompt: str, pil_img) -> dict:
        """استدعاء Gemini مع timeout وإرجاع dict"""
        resp = gemini_client.models.generate_content(
            model=model,
            contents=[prompt, pil_img],
            config=types.GenerateContentConfig(
                temperature=0.1,          # دقة عالية
                max_output_tokens=1024,
            )
        )
        raw = resp.text.strip()
        # تنظيف markdown code blocks
        for fence in ("```json", "```"):
            raw = raw.lstrip(fence)
        raw = raw.rstrip("```").strip()
        return json.loads(raw)

    @staticmethod
    def generate_content(cropped_img, live_data: str, region_code: str, language: str) -> dict:
        region_info = REGION_CONTEXT.get(region_code, REGION_CONTEXT["SA"])
        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        pil = Image.fromarray(cv2.cvtColor(cropped_img, cv2.COLOR_BGR2RGB))

        LANG_MAP = {
            "ar": "Arabic", "en": "English", "fr": "French",
            "es": "Spanish", "zh": "Chinese (Simplified)"
        }
        lang_name = LANG_MAP.get(language, "English")

        # البحث الآن يشمل الويب كاملاً — نُعطي Gemini سياق الريجون فقط بدون قيود أسواق
        prompt = f"""
You are a global product identification and pricing expert.
Analyze the product in this image carefully.

LIVE web data from Google Lens visual search:
{live_data}

CONTEXT:
- User region: {region_info['name']}
- Required currency: {region_info['currency']}
- All text output language: {lang_name} ONLY (no mixing)

INSTRUCTIONS:
1. Identify the product precisely (brand, model, variant if visible).
2. Use the live web data to determine real market prices globally, 
   then convert / estimate the price in {region_info['currency']}.
3. Price sources should be real URLs or store names found in live data.
   If live data is empty, estimate from your knowledge but mark confidence as "low".
4. All string values MUST be in {lang_name} only.
5. Return ONLY a valid JSON object — no markdown, no explanation.

JSON schema:
{{
  "product_name": "string",
  "brand": "string",
  "category": "string",
  "estimated_price": <number in {region_info['currency']}>,
  "price_range": {{"min": <number>, "max": <number>}},
  "price_sources": ["url or store name", "..."],
  "description": "string (2-3 sentences)",
  "confidence": "high|medium|low"
}}

Current time: {now}
"""

        last_err = None
        for model in LLM.MODELS:
            for attempt in range(3):
                try:
                    with Timer(f"Gemini [{model}] محاولة {attempt+1}"):
                        result = LLM._call_gemini(model, prompt, pil)
                    return result
                except Exception as e:
                    last_err = e
                    wait = (attempt + 1) * 2   # 2s, 4s, 6s
                    print(f"⚠️  Gemini error ({model} attempt {attempt+1}): {e}")
                    if "429" in str(e) or "quota" in str(e).lower():
                        print(f"   Rate limit — انتظر {wait}s قبل المحاولة التالية")
                        time.sleep(wait)
                    else:
                        break  # خطأ غير متعلق بـ rate limit — جرّب النموذج التالي
            print(f"⚠️  النموذج {model} فشل، جاري تجربة النموذج التالي...")

        raise RuntimeError(f"All Gemini models failed: {last_err}")


# ── OTP ──────────────────────────────────────────────────────────────────────
SKIP_OTP = True

class Authentication:

    @staticmethod
    def hash_password(pw: str) -> str:
        h = hashlib.sha256(pw.encode()).hexdigest().encode()
        return bcrypt.hashpw(h, bcrypt.gensalt()).decode()

    @staticmethod
    def verify_password(pw: str, hashed: str) -> bool:
        try:
            h = hashlib.sha256(pw.encode()).hexdigest().encode()
            return bcrypt.checkpw(h, hashed.encode())
        except Exception:
            return False

    @staticmethod
    def get_current_user(token: str = Depends(api_key_header)) -> dict:
        if not token:
            raise HTTPException(401, "No token.")
        conn = sqlite3.connect(DB_FILE); c = conn.cursor()
        c.execute("SELECT id, email, role, region FROM users WHERE email=?", (token,))
        row = c.fetchone(); conn.close()
        if not row:
            raise HTTPException(401, "Invalid token.")
        return {"id": row[0], "email": row[1], "role": row[2], "region": row[3] or "SA"}

    @staticmethod
    def send_otp_email(to_email: str, code: str):
        if SKIP_OTP:
            print(f"[OTP DISABLED] Code for {to_email}: {code}")
            return
        if not SMTP_USER or not SMTP_PASS:
            print(f"[DEV] OTP for {to_email}: {code}")
            return
        msg = MIMEMultipart("alternative")
        msg["Subject"] = "Smart Shopper — Verification Code"
        msg["From"]    = SMTP_USER; msg["To"] = to_email
        html = f"""<div style="font-family:Arial;text-align:center;padding:30px">
  <h2 style="color:#6C63FF">Smart Shopper</h2>
  <p>Your verification code:</p>
  <div style="font-size:36px;font-weight:bold;letter-spacing:12px;color:#6C63FF;
    padding:20px;border:2px dashed #6C63FF;border-radius:12px;display:inline-block">{code}</div>
  <p style="color:#888;margin-top:20px">Valid for 5 minutes</p></div>"""
        msg.attach(MIMEText(html, "html"))
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as srv:
            srv.starttls(); srv.login(SMTP_USER, SMTP_PASS)
            srv.sendmail(SMTP_USER, to_email, msg.as_string())


class UserRegister(BaseModel):
    email:      str
    password:   str
    first_name: str
    last_name:  str
    region:     str = "SA"

class UserLogin(BaseModel):
    email: str; password: str

class OTPVerify(BaseModel):
    email: str; code: str

class RoleUpdate(BaseModel):
    role: str


# ─────────────────── Auth Endpoints ───────────────────

@app.post("/register", tags=["Auth"])
async def register(user: UserRegister):
    if len(user.password.strip()) < 6:
        raise HTTPException(422, "Password must be at least 6 characters.")
    if not user.first_name.strip() or not user.last_name.strip():
        raise HTTPException(422, "First and last name are required.")
    if user.region not in REGION_CONTEXT:
        raise HTTPException(422, f"Invalid region. Valid: {list(REGION_CONTEXT.keys())}")
    email = user.email.strip().lower()
    now   = datetime.datetime.now().isoformat()
    try:
        conn = sqlite3.connect(DB_FILE)
        verified = 1 if SKIP_OTP else 0
        conn.execute(
            "INSERT INTO users (email,first_name,last_name,region,password,is_verified,created_at) VALUES (?,?,?,?,?,?,?)",
            (email, user.first_name.strip(), user.last_name.strip(),
             user.region, Authentication.hash_password(user.password.strip()), verified, now)
        )
        conn.commit(); conn.close()
        if not SKIP_OTP:
            code    = str(secrets.randbelow(900000) + 100000)
            expires = (datetime.datetime.now() + datetime.timedelta(minutes=5)).isoformat()
            conn2   = sqlite3.connect(DB_FILE)
            conn2.execute("DELETE FROM otps WHERE email=?", (email,))
            conn2.execute("INSERT INTO otps (email,code,expires_at) VALUES (?,?,?)", (email, code, expires))
            conn2.commit(); conn2.close()
            Authentication.send_otp_email(email, code)
            return {"status": "success", "message": "Registered. Check your email for the verification code."}
        return {"status": "success", "message": "Registered successfully. You can login now."}
    except sqlite3.IntegrityError:
        raise HTTPException(400, "Email already registered.")


@app.post("/send-otp", tags=["Auth"])
async def send_otp(data: UserLogin):
    email = data.email.strip().lower()
    conn  = sqlite3.connect(DB_FILE); c = conn.cursor()
    c.execute("SELECT password FROM users WHERE email=?", (email,))
    row = c.fetchone(); conn.close()
    if not row or not Authentication.verify_password(data.password.strip(), row[0]):
        raise HTTPException(401, "Invalid email or password.")
    if SKIP_OTP:
        conn2 = sqlite3.connect(DB_FILE); c2 = conn2.cursor()
        c2.execute("SELECT role, region FROM users WHERE email=?", (email,))
        r = c2.fetchone(); conn2.close()
        return {"token": email, "role": r[0] if r else "user",
                "region": r[1] if r else "SA", "message": "Login successful (OTP disabled)."}
    code    = str(secrets.randbelow(900000) + 100000)
    expires = (datetime.datetime.now() + datetime.timedelta(minutes=5)).isoformat()
    conn2   = sqlite3.connect(DB_FILE)
    conn2.execute("DELETE FROM otps WHERE email=?", (email,))
    conn2.execute("INSERT INTO otps (email,code,expires_at) VALUES (?,?,?)", (email, code, expires))
    conn2.commit(); conn2.close()
    Authentication.send_otp_email(email, code)
    return {"status": "otp_sent", "message": "Verification code sent to your email."}


@app.post("/verify-otp", tags=["Auth"])
async def verify_otp(data: OTPVerify):
    email = data.email.strip().lower()
    if SKIP_OTP:
        conn = sqlite3.connect(DB_FILE); c = conn.cursor()
        c.execute("SELECT role, region FROM users WHERE email=?", (email,))
        r = c.fetchone(); conn.close()
        return {"token": email, "role": r[0] if r else "user",
                "region": r[1] if r else "SA", "message": "Verified (OTP disabled)."}
    conn  = sqlite3.connect(DB_FILE); c = conn.cursor()
    c.execute("SELECT code, expires_at FROM otps WHERE email=? ORDER BY id DESC LIMIT 1", (email,))
    row = c.fetchone()
    if not row: conn.close(); raise HTTPException(400, "No OTP found.")
    code, expires_at = row
    if datetime.datetime.fromisoformat(expires_at) < datetime.datetime.now():
        conn.close(); raise HTTPException(400, "OTP expired.")
    if data.code.strip() != code:
        conn.close(); raise HTTPException(400, "Incorrect OTP.")
    conn.execute("UPDATE users SET is_verified=1 WHERE email=?", (email,))
    conn.execute("DELETE FROM otps WHERE email=?", (email,))
    conn.commit()
    c.execute("SELECT role, region FROM users WHERE email=?", (email,))
    r = c.fetchone(); conn.close()
    return {"token": email, "role": r[0] if r else "user",
            "region": r[1] if r else "SA", "message": "Verified successfully."}


# ─────────────────── Search Endpoints ───────────────────

@app.post("/crop", tags=["Search"])
async def crop(file: UploadFile = File(...),
               user=Depends(Authentication.get_current_user)):
    raw = await file.read()
    arr = np.frombuffer(raw, np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(422, "Invalid image.")
    with Timer("rembg background removal"):
        cropped = Vision.segment_product(img)
    _, buf  = cv2.imencode('.jpg', cropped, [cv2.IMWRITE_JPEG_QUALITY, 85])
    return {"cropped_image_b64": base64.b64encode(buf.tobytes()).decode(), "format": "jpeg"}


@app.post("/search", tags=["Search"])
async def search(
    file: UploadFile = File(...),
    language:    str  = Query("ar"),
    pre_cropped: bool = Query(False),
    user = Depends(Authentication.get_current_user)
):
    request_start = time.perf_counter()

    raw = await file.read()
    arr = np.frombuffer(raw, np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(422, "Could not decode image.")

    # ── 1. إزالة الخلفية ─────────────────────────────────
    if not pre_cropped:
        with Timer("rembg background removal"):
            cropped = Vision.segment_product(img)
    else:
        cropped = img
        print("⏱  [rembg] تخطّي — الصورة مقصوصة مسبقاً")

    # ── 2. استخراج المتّجه ────────────────────────────────
    with Timer("CLIP vector extraction"):
        vec = Vision.extract_robust_vector(cropped)

    # ── 3. بحث الكاش ─────────────────────────────────────
    with Timer("FAISS cache search"):
        hit = Vision.search_similar(vec)

    total_elapsed = round(time.perf_counter() - request_start, 2)

    if hit and hit["product"]:
        query_fname = f"query_{uuid.uuid4()}.jpg"
        cv2.imwrite(os.path.join(STORAGE_DIR, query_fname), cropped)
        print(f"\n🏁 [CACHE HIT] إجمالي الوقت: {total_elapsed}s | تشابه: {round(hit['similarity']*100,1)}%\n")

        cached_product = hit["product"]
        # إثراء الكاش بمعلومات التشابه
        cached_product["similarity"]     = hit["similarity"]
        cached_product["similarity_pct"] = round(hit["similarity"] * 100, 1)
        cached_product["query_image_url"] = f"/storage/{query_fname}"

        return {
            "source":          "cached",
            "processing_time": total_elapsed,       # ← للفرونت فقط
            "similarity":      hit["similarity"],
            "similarity_pct":  round(hit["similarity"] * 100, 1),
            "query_image_url": f"/storage/{query_fname}",
            "product":         cached_product,
            "similar_products": [],
        }

    region_code = user.get("region", "SA")

    # ── 4. البحث المباشر (Google Lens) ────────────────────
    with Timer("Google Lens visual search"):
        live_data = LiveSearch.get_live_visual_data(cropped, region_code)

    # ── 5. تحليل Gemini ───────────────────────────────────
    try:
        data = LLM.generate_content(cropped, live_data, region_code, language)
    except Exception as e:
        raise HTTPException(500, f"Gemini failed: {e}")

    region_info = REGION_CONTEXT.get(region_code, REGION_CONTEXT["SA"])
    now         = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    fname       = f"{uuid.uuid4()}.jpg"
    cv2.imwrite(os.path.join(STORAGE_DIR, fname), cropped)
    faiss_pos   = faiss_index.ntotal

    # ── 6. حفظ في DB + FAISS ──────────────────────────────
    with Timer("DB + FAISS save"):
        conn = sqlite3.connect(DB_FILE); c = conn.cursor()
        c.execute('''INSERT INTO products
            (user_id,name_enc,brand_enc,price,currency,sources,description,
             category,confidence,image_url,timestamp,language,region,faiss_index)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
            (user["id"], enc(data.get("product_name", "")), enc(data.get("brand", "")),
             data.get("estimated_price", 0), region_info["currency"],
             json.dumps(data.get("price_sources", []), ensure_ascii=False),
             data.get("description", ""), data.get("category", ""),
             data.get("confidence", ""), f"/storage/{fname}", now,
             language, region_code, faiss_pos))
        pid = c.lastrowid; conn.commit(); conn.close()

        faiss_index.add(vec.reshape(1, -1))
        vector_map.append(pid)
        Vision.save_faiss(faiss_index, vector_map)

    total_elapsed = round(time.perf_counter() - request_start, 2)
    print(f"\n🏁 [AI GENERATED] إجمالي الوقت: {total_elapsed}s\n")

    return {
        "source":           "ai_generated",
        "processing_time":  total_elapsed,          # ← للفرونت فقط
        "similar_products": [],
        "product": {
            "id":          pid,
            "name":        data.get("product_name"),
            "brand":       data.get("brand"),
            "category":    data.get("category"),
            "price":       data.get("estimated_price"),
            "currency":    region_info["currency"],
            "price_range": data.get("price_range"),
            "sources":     data.get("price_sources"),
            "description": data.get("description"),
            "confidence":  data.get("confidence"),
            "image_url":   f"/storage/{fname}",
            "timestamp":   now,
            "language":    language,
            "region":      region_code,
        }
    }


# ─────────────────── History / Products ───────────────────

@app.get("/history", tags=["Search"])
async def history(user=Depends(Authentication.get_current_user)):
    conn = sqlite3.connect(DB_FILE); conn.row_factory = sqlite3.Row; c = conn.cursor()
    if user["role"] == "admin":
        c.execute("SELECT * FROM products ORDER BY id DESC")
    else:
        c.execute("SELECT * FROM products WHERE user_id=? ORDER BY id DESC", (user["id"],))
    rows = []
    for r in c.fetchall():
        p = dict(r)
        p["name"]  = dec(p.pop("name_enc", "") or "")
        p["brand"] = dec(p.pop("brand_enc", "") or "")
        rows.append(p)
    conn.close()
    return {"count": len(rows), "products": rows}


@app.get("/products/{product_id}", tags=["Search"])
async def get_product(product_id: int, user=Depends(Authentication.get_current_user)):
    conn = sqlite3.connect(DB_FILE); conn.row_factory = sqlite3.Row; c = conn.cursor()
    c.execute("SELECT * FROM products WHERE id=?", (product_id,))
    row = c.fetchone(); conn.close()
    if not row:
        raise HTTPException(404, "Product not found.")
    p = dict(row)
    p["name"]  = dec(p.pop("name_enc", "") or "")
    p["brand"] = dec(p.pop("brand_enc", "") or "")
    return p


# ─────────────────── Admin ───────────────────

@app.get("/users", tags=["Admin"])
async def get_all_users(user=Depends(Authentication.get_current_user)):
    if user["role"] != "admin":
        raise HTTPException(403, "Admins only.")
    conn = sqlite3.connect(DB_FILE); conn.row_factory = sqlite3.Row; c = conn.cursor()
    c.execute("SELECT id, email, first_name, last_name, region, role, is_verified, created_at FROM users ORDER BY id")
    rows = [dict(r) for r in c.fetchall()]; conn.close()
    return {"count": len(rows), "users": rows}


@app.get("/users/{user_id}", tags=["Admin"])
async def get_user_detail(user_id: int, user=Depends(Authentication.get_current_user)):
    if user["role"] != "admin":
        raise HTTPException(403, "Admins only.")
    conn = sqlite3.connect(DB_FILE); conn.row_factory = sqlite3.Row; c = conn.cursor()
    c.execute("SELECT id,email,first_name,last_name,region,role,is_verified,created_at FROM users WHERE id=?", (user_id,))
    u = c.fetchone()
    if not u: conn.close(); raise HTTPException(404, "User not found.")
    c.execute("SELECT COUNT(*) as cnt, AVG(price) as avg_price FROM products WHERE user_id=?", (user_id,))
    stats = c.fetchone()
    c.execute("SELECT * FROM products WHERE user_id=? ORDER BY id DESC LIMIT 10", (user_id,))
    products = []
    for r in c.fetchall():
        p = dict(r)
        p["name"]  = dec(p.pop("name_enc", "") or "")
        p["brand"] = dec(p.pop("brand_enc", "") or "")
        products.append(p)
    conn.close()
    return {
        "user":     dict(u),
        "stats":    {"total_searches": stats["cnt"], "avg_price": round(stats["avg_price"] or 0, 2)},
        "products": products,
    }


@app.delete("/users/{user_id}", tags=["Admin"])
async def delete_user(user_id: int, user=Depends(Authentication.get_current_user)):
    if user["role"] != "admin":
        raise HTTPException(403, "Admins only.")
    if user_id == user["id"]:
        raise HTTPException(400, "Cannot delete yourself.")
    conn = sqlite3.connect(DB_FILE); c = conn.cursor()
    c.execute("SELECT id FROM users WHERE id=?", (user_id,))
    if not c.fetchone(): conn.close(); raise HTTPException(404, "User not found.")
    c.execute("DELETE FROM products WHERE user_id=?", (user_id,))
    c.execute("DELETE FROM users WHERE id=?", (user_id,))
    conn.commit(); conn.close()
    return {"status": "success", "message": f"User {user_id} deleted."}


@app.delete("/products/{product_id}", tags=["Admin"])
async def delete_product(product_id: int, user=Depends(Authentication.get_current_user)):
    if user["role"] != "admin":
        raise HTTPException(403, "Admins only.")
    conn = sqlite3.connect(DB_FILE); c = conn.cursor()
    c.execute("SELECT faiss_index FROM products WHERE id=?", (product_id,))
    row = c.fetchone()
    if not row: conn.close(); raise HTTPException(404, "Not found.")
    fidx = row[0]
    if fidx is not None and fidx < len(vector_map):
        vector_map[fidx] = -1
        Vision.save_faiss(faiss_index, vector_map)
    c.execute("DELETE FROM products WHERE id=?", (product_id,))
    conn.commit(); conn.close()
    return {"status": "success"}


@app.delete("/products", tags=["Admin"])
async def delete_all_products(user=Depends(Authentication.get_current_user)):
    if user["role"] != "admin":
        raise HTTPException(403, "Admins only.")
    conn = sqlite3.connect(DB_FILE)
    conn.execute("DELETE FROM products")
    conn.commit(); conn.close()
    global faiss_index, vector_map
    faiss_index = faiss.IndexFlatIP(CLIP_DIM); vector_map = []
    Vision.save_faiss(faiss_index, vector_map)
    return {"status": "success", "message": "All products deleted."}


@app.patch("/users/{user_id}/role", tags=["Admin"])
async def update_user_role(user_id: int, body: RoleUpdate,
                           user=Depends(Authentication.get_current_user)):
    if user["role"] != "admin":
        raise HTTPException(403, "Admins only.")
    if body.role not in ("admin", "user"):
        raise HTTPException(422, "role must be 'admin' or 'user'.")
    if user_id == user["id"] and body.role != "admin":
        raise HTTPException(400, "Cannot demote yourself.")
    conn = sqlite3.connect(DB_FILE); c = conn.cursor()
    c.execute("SELECT id FROM users WHERE id=?", (user_id,))
    if not c.fetchone():
        conn.close(); raise HTTPException(404, "User not found.")
    c.execute("UPDATE users SET role=? WHERE id=?", (body.role, user_id))
    conn.commit(); conn.close()
    return {"status": "success", "user_id": user_id, "new_role": body.role}


@app.post("/make-first-admin", tags=["Setup"])
async def make_first_admin(data: UserLogin):
    conn = sqlite3.connect(DB_FILE); c = conn.cursor()
    c.execute("SELECT COUNT(*) FROM users WHERE role='admin'")
    count = c.fetchone()[0]
    if count > 0:
        conn.close()
        raise HTTPException(403, "An admin already exists. Use /users/{id}/role instead.")
    email = data.email.strip().lower()
    c.execute("SELECT password FROM users WHERE email=?", (email,))
    row = c.fetchone()
    if not row or not Authentication.verify_password(data.password.strip(), row[0]):
        conn.close(); raise HTTPException(401, "Invalid credentials.")
    c.execute("UPDATE users SET role='admin' WHERE email=?", (email,))
    conn.commit(); conn.close()
    return {"status": "success", "message": f"{email} is now admin."}


@app.get("/health", tags=["System"])
async def health():
    return {"status": "ok", "faiss_total": faiss_index.ntotal, "db": os.path.exists(DB_FILE)}


@app.get("/regions", tags=["System"])
async def get_regions():
    return {"regions": [{"code": k, "name": v["name"], "currency": v["currency"]}
                        for k, v in REGION_CONTEXT.items()]}