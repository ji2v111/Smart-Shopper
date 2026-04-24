# Smart Shopper - Frontend Setup Guide

## 🚀 خطوات التشغيل

### 1. المتطلبات
- Flutter SDK 3.x
- Dart SDK 3.x
- Android Studio / VS Code
- Android Emulator أو جهاز حقيقي

### 2. تثبيت الحزم
```bash
cd smart_shopper_frontend
flutter pub get
```

### 3. تشغيل التطبيق
```bash
flutter run
```

---

## ⚙️ إعداد الـ Base URL

افتح الملف:
```
lib/services/api_service.dart
```

غير السطر التالي حسب بيئتك:

| البيئة | القيمة |
|---|---|
| Android Emulator | `http://10.0.2.2:8000` ✅ (الافتراضي) |
| iOS Simulator | `http://localhost:8000` |
| جهاز Android/iOS حقيقي | `http://192.168.x.x:8000` (IP جهاز الكمبيوتر) |

---

## 📁 هيكل المشروع

```
lib/
├── main.dart                    # نقطة الدخول + Splash
├── app_state.dart               # إدارة الحالة (Theme / Language)
├── theme.dart                   # ألوان وستايل التطبيق
├── l10n.dart                    # ترجمات (ar, en, fr, es, zh)
├── data/
│   └── regions.dart             # قائمة الدول والعملات
├── services/
│   └── api_service.dart         # جميع طلبات الـ API
├── widgets/
│   └── error_handler.dart       # SnackBar للأخطاء والنجاح
└── screens/
    ├── onboarding_screen.dart   # شاشة الترحيب (أول مرة)
    ├── login_screen.dart        # تسجيل الدخول
    ├── register_screen.dart     # إنشاء حساب
    ├── otp_screen.dart          # التحقق برمز OTP
    ├── home_screen.dart         # الشاشة الرئيسية (Bottom Nav)
    ├── search_screen.dart       # رفع صورة وتحليل المنتج
    ├── history_screen.dart      # سجل البحث
    ├── product_detail_screen.dart # تفاصيل المنتج والسعر
    ├── admin_screen.dart        # لوحة الأدمن
    ├── user_detail_screen.dart  # تفاصيل المستخدم (أدمن)
    └── settings_screen.dart     # الإعدادات
```

---

## 🔧 المشاكل الشائعة وحلولها

### ❌ `No pubspec.yaml file found`
تأكد أنك داخل مجلد المشروع الصحيح قبل تشغيل أي أمر:
```bash
cd smart_shopper_frontend
flutter pub get
```

### ❌ لا يتصل بالـ Backend
- تأكد أن الـ backend شغال على port 8000
- تأكد من صحة الـ `baseUrl` في `api_service.dart`
- على الجهاز الحقيقي استخدم IP الكمبيوتر (مش localhost)

### ❌ خطأ في الكاميرا أو الصور
تأكد من وجود الـ permissions في `AndroidManifest.xml` (موجودة بالفعل)
