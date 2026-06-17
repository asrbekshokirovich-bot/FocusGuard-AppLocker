# FocusGuard — Play Market talablariga muvofiqlik (Compliance) cheklisti

Bu ilova **sezgir ruxsatlar** (AccessibilityService, Usage Access, QUERY_ALL_PACKAGES,
overlay) ishlatadi. Play Console'da quyidagilarni to'g'ri to'ldirmasangiz, ilova
**rad etiladi**. Har birini bajaring.

## ✅ Kod tomonida bajarilgan (shu loyihada)
- [x] Release imzolash (keystore + GitHub Secrets)
- [x] AAB build (App Bundle) — Play faqat AAB qabul qiladi
- [x] targetSdk 36 (Play 2025 talabi: target ≥ 35)
- [x] **Hisobni o'chirish** (Profil → "Hisobni o'chirish") — login bor ilovalar uchun MAJBURIY
- [x] Ishlatilmaydigan `USE_FULL_SCREEN_INTENT` ruxsati olib tashlandi
- [x] Foreground service turi `specialUse` (Android 14+)
- [x] Ruxsatlar ekranida har bir ruxsat nega kerakligi izohlangan (prominent disclosure)

## ⚠️ Play Console'da SIZ to'ldirishingiz shart

### 1. AccessibilityService deklaratsiyasi (ENG MUHIM — busiz rad etiladi)
Play Console → **Policy → App content → "Accessibility API"** (yoki Permissions
declaration):
- "Does your app use the AccessibilityService API?" → **Yes**
- Tushuntirish (ko'chiring):
  > FocusGuard is a focus & app-blocking tool. It uses AccessibilityService to
  > detect when a user-selected blocked app comes to the foreground, and then
  > shows a blocking screen to help the user avoid distractions. It does not
  > collect or read screen content; it only reads the foreground package name
  > of apps the user explicitly chose to block.
- Demo video / qo'llanma so'ralishi mumkin — bloklash ishlashini ko'rsating.

### 2. Sezgir ruxsatlar deklaratsiyasi
**App content → "Sensitive app permissions"**:
- **QUERY_ALL_PACKAGES** → "App functionality is to block/manage other apps
  (app blocker / digital wellbeing). The user selects which installed apps to
  block, so the app must show the full installed-apps list."
- **Usage Access (PACKAGE_USAGE_STATS)** → "Used to detect distracting app usage
  and to power blocking + statistics for the user."
- **Exact alarm (USE_EXACT_ALARM)** → "Used to deliver user-set focus reminders
  and plan notifications at exact times."
- **specialUse foreground service** → "A persistent service supports app blocking
  and the focus timer while the app is in the background."

### 3. Maxfiylik siyosati (Privacy Policy) — MAJBURIY URL
`PRIVACY_POLICY.md` matnini ochiq sahifaga joylang (GitHub Pages, Google Sites
yoki oddiy sayt) → URL'ini **Store presence → App content → Privacy Policy** ga qo'ying.

### 4. Data safety formasi
**App content → Data safety**:
- Yig'iladigan ma'lumotlar: **Email, Name** (account), **App activity / usage stats**.
- "Is data encrypted in transit?" → **Yes** (Firebase HTTPS).
- "Can users request data deletion?" → **Yes** → ilovada "Hisobni o'chirish" bor.
- Reklama uchun ulashilmaydi, sotilmaydi.

### 5. Content rating
**App content → Content rating** anketasini to'ldiring → odatda **Everyone / 3+**.

### 6. Target audience
**App content → Target audience** → 13+ (yoki sizning auditoriyangiz). Bolalarga
mo'ljallanmagan deb belgilang.

### 7. App access (agar login talab qilsa)
**App content → App access** → ilova login talab qilsa, **test akkaunt**
(email+parol) bering, shunda Google tekshiruvchisi kira oladi.

### 8. Store listing aktivlari
- App icon 512×512 (`assets/logo.png` asosida)
- Feature graphic 1024×500
- Kamida 2 ta telefon skrinshoti (fokus, bloklash, statistika ekranlari)
- Matnlar: `PLAY_STORE_LISTING.md`

## Yuklash tartibi
1. **Production → Create release** → imzolangan `.aab` ni yuklang
2. Yuqoridagi barcha "App content" bo'limlarini ✅ qiling (Dashboard ularni ko'rsatadi)
3. **Send for review** → 1–7 kun

> Eslatma: AccessibilityService + Usage Access kombinatsiyasi Google tomonidan
> diqqat bilan tekshiriladi. Tushuntirishlar aniq va halol bo'lsa — "app blocker"
> toifasi sifatida ruxsat beriladi (AppBlock, Stay Focused kabi).
</content>
