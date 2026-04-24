"""
أداة إنشاء أول أدمن — Smart Shopper
استخدم هذا السكريبت مرة واحدة فقط لترقية حساب موجود كأدمن.
"""
import sqlite3, getpass, hashlib, bcrypt

DB_FILE = "smart_shopper.db"

def verify_password(pw, hashed):
    h = hashlib.sha256(pw.encode()).hexdigest().encode()
    return bcrypt.checkpw(h, hashed.encode())

conn = sqlite3.connect(DB_FILE)
c = conn.cursor()

c.execute("SELECT COUNT(*) FROM users WHERE role='admin'")
if c.fetchone()[0] > 0:
    print("⚠️  يوجد أدمن بالفعل. استخدم /users/{id}/role API من لوحة التحكم.")
    conn.close()
    exit()

email = input("البريد الإلكتروني للحساب: ").strip().lower()
c.execute("SELECT id, password FROM users WHERE email=?", (email,))
row = c.fetchone()
if not row:
    print("❌ البريد غير موجود")
    conn.close(); exit()

pw = getpass.getpass("كلمة المرور: ")
if not verify_password(pw, row[1]):
    print("❌ كلمة المرور غير صحيحة")
    conn.close(); exit()

c.execute("UPDATE users SET role='admin' WHERE email=?", (email,))
conn.commit(); conn.close()
print(f"✅ تم ترقية {email} كأدمن بنجاح!")
