import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

# ---------------------------------------------------------
# 1. ตั้งค่าการเชื่อมต่อ (เปลี่ยน path ให้ตรงกับไฟล์ key ของคุณ)
# ---------------------------------------------------------
cred = credentials.Certificate("serviceAccountKey.json") 
firebase_admin.initialize_app(cred)

db = firestore.client()

def migrate_quiz_collection():
    print("🚀 เริ่มต้นกระบวนการย้ายข้อมูล...")

    # Path ต้นทาง: questions -> g_1 -> quiz
    source_collection_ref = db.collection('questions').document('g_3').collection('quiz')
    
    # Path ปลายทาง: questions -> g_1 -> quiz_1
    dest_collection_ref = db.collection('questions').document('g_3').collection('quiz_3')

    # ดึงข้อมูลทั้งหมดจากต้นทาง
    docs = source_collection_ref.stream()
    
    # ใช้ Batch เพื่อความเร็วและประหยัด quota (Firestore batch จำกัด 500 รายการ)
    batch = db.batch()
    count = 0
    total_moved = 0
    
    doc_list = list(docs) # แปลงเป็น list เพื่อวนลูป
    
    if not doc_list:
        print("❌ ไม่พบข้อมูลใน collection ต้นทาง ('quiz')")
        return

    print(f"📦 พบเอกสารทั้งหมด {len(doc_list)} รายการ กำลังดำเนินการ...")

    # ---------------------------------------------------------
    # 2. ขั้นตอนการคัดลอกข้อมูล (Copy Data)
    # ---------------------------------------------------------
    for doc in doc_list:
        data = doc.to_dict()
        
        # สร้างเอกสารใหม่ใน quiz_1 ด้วย ID เดิม
        new_doc_ref = dest_collection_ref.document(doc.id)
        batch.set(new_doc_ref, data)
        
        count += 1
        total_moved += 1

        # ถ้าครบ 400 รายการ ให้บันทึกก่อน (กัน Batch เต็ม)
        if count >= 400:
            batch.commit()
            print(f"   ...บันทึกแล้ว {total_moved} รายการ")
            batch = db.batch() # เริ่ม batch ใหม่
            count = 0

    # บันทึกส่วนที่เหลือ
    if count > 0:
        batch.commit()
        print(f"   ...บันทึกชุดสุดท้ายเรียบร้อย")

    print("✅ คัดลอกข้อมูลไปยัง 'quiz_1' เสร็จสมบูรณ์!")

    # ---------------------------------------------------------
    # 3. ขั้นตอนการลบข้อมูลเก่า (Delete Old Data)
    # ⚠️ ปลอดภัยไว้ก่อน: ผมทำเป็น comment ไว้ ถ้ามั่นใจให้เอา # ออก
    # ---------------------------------------------------------
    
    # confirm = input("⚠️ ต้องการลบข้อมูลใน collection เก่า ('quiz') หรือไม่? (y/n): ")
    # if confirm.lower() == 'y':
    #     delete_batch = db.batch()
    #     del_count = 0
        
    #     for doc in doc_list:
    #         # อ้างอิงเอกสารเดิมเพื่อลบ
    #         delete_batch.delete(doc.reference)
    #         del_count += 1
            
    #         if del_count >= 400:
    #             delete_batch.commit()
    #             delete_batch = db.batch()
    #             del_count = 0
        
    #     if del_count > 0:
    #         delete_batch.commit()
            
    #     print("🗑️ ลบข้อมูลใน 'quiz' (g_1) เรียบร้อยแล้ว")
    # else:
    #     print("ℹ️ ไม่ได้ลบข้อมูลเก่า (ข้อมูลยังอยู่ใน 'quiz')")

if __name__ == "__main__":
    migrate_quiz_collection()