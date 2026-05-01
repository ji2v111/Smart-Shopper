# Smart Shopper

## Project Overview

Smart Shopper is an AI-powered product identification and price estimation system. A user photographs any retail product with the Flutter mobile app; the server identifies the product, retrieves real-time pricing from the web, and returns a structured result in the user's chosen language and regional currency.

The system solves two core problems simultaneously:

- **Consumer experience**: replaces slow text-based search with instant image-based identification.
- **Cost and latency**: a Visual Semantic Cache (FAISS + CLIP) avoids redundant AI calls — if a similar product was searched before, the cached result is returned within 2 seconds without reaching Gemini.

The backend is built with FastAPI and structured according to the Layered MVC architecture described in the Software Engineering report.

---

## Technology Stack

### Backend
| Layer | Technology |
|-------|-----------|
| API Framework | FastAPI (Python 3.10+) |
| Visual AI | CLIP (`openai/clip-vit-base-patch32`) via HuggingFace Transformers |
| LLM | Google Gemini 2.5 Pro / Flash (with built-in Google Search tool) |
| Vector Database | FAISS (Facebook AI Similarity Search) |
| Relational Database | SQLite 3 |
| Background Removal | rembg |
| Encryption | Fernet (cryptography) + bcrypt |
| Image Processing | OpenCV, Pillow |
| Authentication | Email + Password (with optional OTP) |

### Frontend
| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart) |
| State Management | Provider |
| HTTP Client | http |
| Local Storage | shared_preferences |
| Languages | Arabic · English · French · Spanish · Chinese |

---

## Project Structure

```
smart_shopper/
│
├── backend/
│   ├── storage/               # Temporary storage for cropped/processed images
│   ├── .env.example           # Environment variable template
│   ├── main.py                # Core application: API routes, LLM logic, Vision, DB
│   ├── requirements.txt       # Python dependencies
│   ├── setup_admin.py         # Script to bootstrap the initial admin account
│   ├── setup_server.sh        # Shell script for automated server environment setup
│   └── update.sh              # Shell script for fetching updates and restarting services
│
└── frontend/
    └── lib/
        ├── main.dart                        # App entry point, theme & routing
        ├── app_state.dart                   # Global state (theme, language, region)
        ├── theme.dart                       # Light/dark monochrome design system
        ├── l10n.dart                        # Localization strings (5 languages)
        ├── data/
        │   └── regions.dart                 # Supported regions & currencies
        ├── services/
        │   └── api_service.dart             # All HTTP calls to the backend
        ├── screens/
        │   ├── onboarding_screen.dart       # First-launch walkthrough
        │   ├── login_screen.dart            # Login with email + password
        │   ├── register_screen.dart         # New account registration
        │   ├── otp_screen.dart              # OTP verification
        │   ├── home_screen.dart             # Main navigation shell
        │   ├── search_screen.dart           # Image upload + product analysis
        │   ├── history_screen.dart          # User search history
        │   ├── product_detail_screen.dart   # Single product detail view
        │   ├── settings_screen.dart         # Theme, language, logout
        │   ├── admin_screen.dart            # Admin panel (users + products)
        │   └── user_detail_screen.dart      # Admin: per-user detail & stats
        └── widgets/
            └── error_handler.dart           # Centralized error snackbar
```

---

## Backend — Setup and Installation

### 1. Prerequisites

Ensure Python 3.10+ is installed. Then clone the repository and navigate into it:

```bash
git clone https://github.com/<your-username>/smart-shopper-api.git
cd smart-shopper-api
```

### 2. Create a Virtual Environment

```bash
# Create virtual environment
python -m venv venv

# Activate it
source venv/bin/activate          # macOS / Linux
venv\Scripts\activate             # Windows
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

> **Note:** Installing `torch` and `transformers` will download the CLIP model (~600 MB) on first run. Ensure a stable internet connection.

### 4. Configure Environment Variables

Copy the template and fill in your API keys:

```bash
cp .env.example .env
```

Edit `.env` and provide:

| Variable | Description |
|----------|-------------|
| `GEMINI_API_KEY` | Google Gemini API key |
| `SERPAPI_KEY` | SerpApi key (reserved for future use) |
| `IMGBB_KEY` | ImgBB image hosting key (reserved for future use) |
| `DB_SECRET_KEY` | Any 32+ character string for field-level encryption |
| `SMTP_USER` / `SMTP_PASS` | Gmail address + App Password (for OTP emails) |

### 5. Running the Server

```bash
python main.py
```

The server starts at `http://localhost:8000`.

Interactive API documentation is available at `http://localhost:8000/docs` (Swagger UI).

---

## Frontend — Setup and Installation

### 1. Prerequisites

Ensure Flutter 3.x is installed and configured:

```bash
flutter doctor
```

### 2. Install Dependencies

```bash
cd frontend
flutter pub get
```

### 3. Configure the Base URL

In `lib/services/api_service.dart`, update `baseUrl` to point to your running backend:

```dart
// Android emulator → localhost
static const String baseUrl = "http://10.0.2.2:8000";

// Real device or remote server
static const String baseUrl = "https://your-server.com";
```

### 4. Run the App

```bash
flutter run
```


---

## Visual Semantic Cache — How It Works

```
User uploads image
       ↓
rembg removes background
       ↓
CLIP extracts 512-dim feature vector
       ↓
FAISS searches for similar cached vector (threshold: 87% similarity)
       ↓
   ┌───┴───┐
HIT ✅      MISS ❌
   ↓           ↓
Return     Gemini 2.5 Pro
cached     (built-in Google Search)
result     → save to DB + FAISS
(< 2s)     → return new result
```

The cache is **language-aware**: an Arabic search result will not be returned for an English query, even if the product image is identical.

---

## Supported Regions

| Code | Country | Currency |
|------|---------|----------|
| SA | Saudi Arabia | SAR |
| AE | UAE | AED |
| KW | Kuwait | KWD |
| QA | Qatar | QAR |
| EG | Egypt | EGP |
| US | USA | USD |
| GB | UK | GBP |
| DE | Germany | EUR |
| FR | France | EUR |
| CN | China | CNY |
| ES | Spain | EUR |
| TR | Turkey | TRY |
| IN | India | INR |
| JP | Japan | JPY |