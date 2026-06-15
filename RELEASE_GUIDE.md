# FocusGuard — AAB qurish va Play Market'ga joylash

## 1. AAB faylni olish (eng oson — CI orqali)

Har `push`/PR'da GitHub Actions **`release-aab`** artifact'ini quradi.

1. GitHub → **Actions** → eng so'nggi yashil build'ni oching
2. Pastda **Artifacts** → **`release-aab`** ni yuklab oling
3. `.zip` ichidan `app-release.aab` chiqadi — shu Play Console'ga yuklanadi

> ⚠️ AAB Play'ga yuklanishi uchun **release kalit bilan imzolangan** bo'lishi
> shart. Quyidagi 2-bo'limni bajaring, aks holda AAB debug kalit bilan
> imzolanadi va Play uni qabul qilmaydi.

## 2. Release kalit (keystore) yaratish — bir martalik

Kompyuteringizda (Java o'rnatilgan bo'lishi kerak):

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- Parol so'raydi — **eslab qoling/saqlang** (yo'qotsangiz, ilovani yangilay olmaysiz!)
- `upload-keystore.jks` fayli yaratiladi.

### Keystore'ni base64 ga aylantirish (CI uchun)
```bash
# Linux/Mac:
base64 -w0 upload-keystore.jks > keystore_base64.txt
# Mac (agar -w0 ishlamasa):
base64 -i upload-keystore.jks -o keystore_base64.txt
```

## 3. GitHub Secrets qo'shish

GitHub → repo → **Settings → Secrets and variables → Actions → New repository secret**.
4 ta secret qo'shing:

| Secret nomi | Qiymati |
|-------------|---------|
| `KEYSTORE_BASE64` | `keystore_base64.txt` ichidagi to'liq matn |
| `KEYSTORE_PASSWORD` | keystore par? (2-qadamdagi parol) |
| `KEY_ALIAS` | `upload` |
| `KEY_PASSWORD` | key paroli (odatda keystore paroli bilan bir xil) |

Shundan keyin har yangi build'dagi `release-aab` **release kalit bilan
imzolangan** bo'ladi va to'g'ridan-to'g'ri Play'ga yuklanadi.

## 4. Lokal qurish (xohlasangiz, kompyuterda)

`android/key.properties` faylini yarating (repoga qo'shilmaydi — `.gitignore`'da):
```properties
storeFile=/to/liq/yo'l/upload-keystore.jks
storePassword=PAROL
keyAlias=upload
keyPassword=PAROL
```
Keyin:
```bash
flutter build appbundle --release
# Natija: build/app/outputs/bundle/release/app-release.aab
```

## 5. versionCode / versionName

Har Play yangilanishida `versionCode` oshishi SHART. `pubspec.yaml`:
```yaml
version: 1.0.0+1   # +1 = versionCode. Keyingi yuklashda 1.0.1+2 qiling.
```

## 6. Play Console'da joylash tartibi

1. https://play.google.com/console → **Create app**
2. App nomi, til, "App or game" → App, "Free/Paid" tanlang
3. **Main store listing** — `PLAY_STORE_LISTING.md` dagi matnlarni ko'chiring
4. **Privacy policy URL** qo'ying (`PRIVACY_POLICY.md` ni saytga/Gist'ga joylang)
5. **Data safety**, **Content rating**, **Target audience** anketalarini to'ldiring
6. **Production → Create release** → `app-release.aab` ni yuklang
7. Tekshiruvga yuboring (1–7 kun)

> Play "App Signing" yoqilgan bo'lsa, sizning keystore — "upload key" bo'ladi;
> Google o'z kaliti bilan qayta imzolaydi. Bu normal va tavsiya etiladi.
</content>
