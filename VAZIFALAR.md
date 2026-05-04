# Android App Locker: Vazifalar ro'yxati

- [x] **1-qadam: Kerakli paketlarni o'rnatish**
  - `device_apps` (Barcha ilovalar ro'yxatini va logotiplarini olish uchun) O'RNATILDI
  - `app_usage` (Qaysi ilova faol ekanini kuzatish uchun)
  - `system_alert_window` yoki `flutter_overlay_window` (Bloklash ekranini boshqa ilovalar ustidan ko'rsatish uchun)
  - `flutter_background_service` (Ilova yopiq bo'lsa ham kodlarimiz orqa fonda ishlashda davom etishi uchun)

- [x] **2-qadam: AndroidManifest.xml fayliga ruxsatlarni qo'shish**
  - `QUERY_ALL_PACKAGES` (Barcha ilovalarni ko'rish ruxsati) BAJARILDI
  - `PACKAGE_USAGE_STATS` (Foydalanish tarixiga ruxsat) BAJARILDI
  - `SYSTEM_ALERT_WINDOW` (Boshqa ilovalar ustida ko'rsatish ruxsati) BAJARILDI
  - `FOREGROUND_SERVICE` (Orqa fonda to'xtovsiz ishlash ruxsati) BAJARILDI

- [x] **3-qadam: Flutter'da Ruxsat (Permissions) so'rash oynasini yaratish**
  - Foydalanuvchiga nima uchun bu ruxsatlar kerakligini tushuntiruvchi ekran. BAJARILDI
  - Foydalanuvchini to'g'ridan-to'g'ri telefon Sozlamalaridagi (Settings) ruxsat berish bo'limiga yo'naltirish. BAJARILDI

- [x] **4-qadam: Ilovalar ro'yxati ekranini (App List Screen) qurish**
  - Telefonga o'rnatilgan ilovalarni (ismi va ikonkasini) ekranga chiqarish. BAJARILDI
  - Har bir ilova yoniga Bloklash/Ochish (Switch) tugmasini qo'yish. BAJARILDI
  - Tanlangan (bloklangan) ilovalar ro'yxatini xotirada saqlash (`SharedPreferences`). BAJARILDI

- [x] **5-qadam: Orqa fon xizmati (Background Service) va Bloklash algoritmi**
  - Telefon yoqilishi bilan orqa fon xizmatini avtomatik ishga tushirish. BAJARILDI
  - Har 1-2 soniyada ekrandagi faol ilova (Foreground App) nomini tekshirish. BAJARILDI
  - Agar faol ilova nomi (masalan `com.instagram.android`) biz bloklagan ro'yxatda bo'lsa, zudlik bilan ustiga "Bu ilova Focus Guard tomonidan bloklangan" degan ekranni bostirish. BAJARILDI
