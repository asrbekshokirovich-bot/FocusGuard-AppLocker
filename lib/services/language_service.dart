import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:google_fonts/google_fonts.dart';

class LanguageService {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  static const String _langKey = 'selected_language';
  String _currentLanguage = 'uz';
  final ValueNotifier<String> languageNotifier = ValueNotifier<String>('uz');

  static TextStyle getFont({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) {
    final langCode = LanguageService().currentLanguage;
    if (langCode == 'ko') {
      return GoogleFonts.notoSansKr(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        decoration: decoration,
      );
    }
    return GoogleFonts.inter(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
    );
  }

  String get currentLanguage => _currentLanguage;

  // Initialize service and load saved language
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString(_langKey) ?? 'uz';
    languageNotifier.value = _currentLanguage;
  }

  // Save language to storage
  Future<void> setLanguage(String code) async {
    _currentLanguage = code;
    languageNotifier.value = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, code);
  }

  // Update language in memory only for immediate UI response
  void setLanguageImmediate(String code) {
    _currentLanguage = code;
    languageNotifier.value = code;
  }

  /// Belgilangan tilda tarjimani olish — global tilga ta'sir qilmaydi.
  /// Legal screen ichida til chiplari uchun ishlatiladi: foydalanuvchi
  /// faqat shu sahifada boshqa tilda o'qishi mumkin, ilova umumiy tili
  /// o'zgarmaydi.
  dynamic translateInLang(String key, String langCode) {
    final lang = _translations[langCode] ?? _translations['en']!;
    dynamic value = lang;
    for (final part in key.split('.')) {
      if (value is Map && value.containsKey(part)) {
        value = value[part];
      } else {
        return null;
      }
    }
    return value;
  }

  // Translation data for initial flow (Splash, Language Select, Onboarding, Auth)
  static final Map<String, Map<String, dynamic>> _translations = {
    'uz': {
      'language': {
        'title': 'Tilni Tanlang',
        'subtitle': 'Davom etish uchun ilova tilini tanlang.',
        'continue': 'Davom etish',
      },
      'common': {
        'continue': 'Davom etish',
        'back': 'Orqaga',
        'save': 'Saqlash',
        'login': 'Tizimga Kirish',
        'cancel': 'Bekor qilish'
      },
      'onboarding': [
        {
          'title': 'Chuqur Diqqat Markazi',
          'text':
              'Ijtimoiy tarmoqlar va keraksiz xabarlarni o\'chirib, faqat muhim maqsadga diqqat qiling.'
        },
        {
          'title': 'Zararli Ilovalarni Qulflash',
          'text':
              'Vaqtingizni o\'g\'irlaydigan ilovalarni bloklang va kuningizni unumli faoliyatga yo\'naltiring.'
        },
        {
          'title': 'Samaradorlik Tahlili',
          'text':
              'Daqiqalaringiz qayerga sarflanayotganini kuzatib, barcha natijalaringizni tahlil qiling.'
        },
      ],
      'login': {
        'welcome': 'Xush Kelibsiz.',
        'subtitle':
            'Tizimga kirish uchun shaxsiy ma\'lumotlaringizni\nkiriting.',
        'email_hint': 'Username@gmail.com',
        'password_label': 'PAROL',
        'password_hint': '••••••••',
        'no_account': 'Hisobingiz yo\'qmi? ',
        'register': 'Ro\'yxatdan o\'tish',
        'terms': 'Foydalanuvchi shartlari va Maxfiylik siyosati',
        'forgot_password': 'Kod yodingizdan chiqdimi?',
        'forgot_password_title': 'Parolni Tiklash',
        'forgot_password_desc':
            'Ro\'yxatdan o\'tgan pochtangizni kiriting. Biz sizga parolni yangilash havolasini yuboramiz.',
        'reset_link_sent':
            'Havola Gmail pochtangizga yuborildi. Iltimos, pochtangizni tekshiring.',
        'welcome_back': 'Xush kelibsiz, {name}!',
      },
      'register': {
        'title': 'Ro\'yxatdan O\'tish',
        'subtitle': 'Yangi hisob yaratish uchun ma\'lumotlarni kiriting.',
        'name_label': 'ISM FAMILIYA',
        'name_hint': 'Ismingizni kiriting',
        'email_label': 'POCHTA',
        'password_label': 'PAROL',
        'confirm_password_label': 'PAROLNI TASDIQLASH',
        'have_account': 'Hisobingiz bormi? ',
        'login_now': 'Kirish',
        'welcome_new': 'Muvaffaqiyatli ro\'yxatdan o\'tdingiz, {name}!',
        'check_spam':
            'Tasdiqlash xati yuborildi. Agar Inbox\'da bo\'lmasa, Spam papkasini ham tekshiring.',
      },
      'legal': {
        'title': 'Foydalanish shartlari va Maxfiylik siyosati',
        'close': 'Yopish',
        'sections': [
          {
            'title': '1. Ilova haqida',
            'content':
                'FocusGuard — diqqatni jamlash va mahsuldorlikni oshirishga yordam beruvchi ilova. Pomodoro taymeri, chalg\'ituvchi ilovalarni bloklash, kunlik statistika va eslatmalar funksiyalari mavjud.'
          },
          {
            'title': '2. Hisob va xavfsizlik',
            'content':
                'Ilovadan foydalanish uchun haqiqiy email manzili orqali hisob ochasiz. Sizning email, parol va shaxsiy ma\'lumotlaringiz himoyalangan tarzda saqlanadi. Parol va hisob xavfsizligi shaxsiy javobgarlikingizdadir — uni hech kim bilan baham ko\'rmang. Hisobingizdan ruxsatsiz foydalanilganini sezsangiz, darhol parolni o\'zgartiring va biz bilan bog\'laning.'
          },
          {
            'title': '3. To\'g\'ri foydalanish',
            'content':
                'Ilovani teskari muhandislik qilish, dekompilyatsiya yoki manba kodini o\'zgartirishga urinish taqiqlanadi. Boshqa foydalanuvchilarning hisoblariga ruxsatsiz kirish, statistika, daraja yoki XP\'ni soxtalashtirish, avtomatlashtirilgan vositalar (bot, skript) ishlatish taqiqlanadi. Ilovadan noqonuniy, zararli yoki uchinchi shaxslarning huquqlariga zid maqsadlarda foydalanish mumkin emas. Ushbu qoidalarni buzish hisobingizning bekor qilinishiga olib keladi.'
          },
          {
            'title': '4. Premium obuna',
            'content':
                'Ilova bepul foydalanish uchun ochiq. Premium obuna qo\'shimcha imkoniyatlar beradi: cheksiz bulutli tarix (bepul foydalanuvchilarda so\'nggi 7 kun saqlanadi), kengaytirilgan tahlil funksiyalari va kelajakda qo\'shilishi mumkin bo\'lgan boshqa imtiyozli xizmatlar. Obuna sotuvi siz ilovani yuklab olgan rasmiy ilovalar do\'koni (App Store yoki Google Play) orqali amalga oshiriladi va o\'sha do\'kon qoidalariga bo\'ysunadi. Pul qaytarish so\'rovlari shu do\'kon orqali yuboriladi.'
          },
          {
            'title': '5. Qaysi ma\'lumotlar to\'planadi',
            'content':
                'Hisobingiz uchun: email manzil, parol (shifrlangan), ism va ro\'yxatdan o\'tgan sana. Foydalanish uchun: daraja, XP, fokus tarixi, kunlik vaqt, bajarilgan seanslar, rejalar va faoliyatlar. Bu ma\'lumotlar himoyalangan bulutli serverlarda saqlanadi va qurilma o\'zgartirsangiz tiklanadi. Bloklangan ilovalar ro\'yxati, ilova ikonkalari va sozlamalar (til, tema, bildirishnoma toggle\'lari) faqat sizning qurilmangizda qoladi va serverga yuborilmaydi.'
          },
          {
            'title': '6. Qaysi ma\'lumotlar to\'planmaydi',
            'content':
                'Biz hech qachon quyidagi ma\'lumotlarni yig\'maymiz: joylashuv (GPS), telefon raqami, aloqalar (kontaktlar), SMS, qo\'ng\'iroqlar tarixi, foto, video, audio fayllar, mikrofon yoki kamera yozuvlari, brauzer tarixi va boshqa ilovalardagi shaxsiy ma\'lumotlar. Reklama identifikatori va kuzatuvchi vositalar yo\'q. Bizning yagona maqsadimiz — sizga mahsuldor fokus tajribasini berish.'
          },
          {
            'title': '7. Ma\'lumotlardan foydalanish',
            'content':
                'Yig\'ilgan ma\'lumotlar faqat ilovaning asosiy funksiyalari uchun ishlatiladi: hisobingizni saqlash va autentifikatsiya qilish, statistikangiz va darajangizni ko\'rsatish, belgilangan vaqtda eslatma yuborish, obuna holatini aniqlash, qurilma o\'zgartirsangiz ma\'lumotlarni tiklash, ilova xatolarini tuzatish va sifatni oshirish. Ma\'lumotlaringiz hech qachon reklama maqsadida sotilmaydi, marketingda ishlatilmaydi va profilingiz tijoriy maqsadda tahlil qilinmaydi.'
          },
          {
            'title': '8. Talab qilinadigan ruxsatlar',
            'content':
                'Ilova ishlashi uchun ba\'zi qurilma ruxsatlari so\'raladi: bildirishnoma yuborish (eslatmalar va taymer tugashi xabarlari), ilova foydalanish statistikasi (bloklangan ilovaning ochilishini aniqlash uchun), ustki qatlam (bloklash ekranini ko\'rsatish), aniq vaqtli signal (rejalar uchun), Sukut rejimini boshqarish (Anti-Chalg\'itish funksiyasi uchun) va fonda ishlash (taymer va bloklash xizmatining uzluksiz ishlashi uchun). Barcha ruxsatlar faqat ilova ichida ishlatiladi va serverga uzatilmaydi. Har qanday ruxsatni qurilma sozlamalaridan istalgan vaqtda bekor qilishingiz mumkin.'
          },
          {
            'title': '9. Foydalanuvchi huquqlari',
            'content':
                'Siz istalgan vaqtda quyidagi huquqlardan foydalanishingiz mumkin: ma\'lumotlaringizni ko\'rish, noto\'g\'ri yoki eskirgan ma\'lumotlarni tuzatish, ma\'lumotlaringizni eksport qilish va hisobingizni butunlay o\'chirish. Hisobni o\'chirish so\'rovi 30 kun ichida bajariladi — bu vaqt mobaynida xato qilingan bo\'lsa hisobni tiklash mumkin. 30 kundan keyin barcha ma\'lumotlar tiklab bo\'lmaydigan tarzda o\'chiriladi. So\'rov yuborish uchun: focusguard.app@gmail.com.'
          },
          {
            'title': '10. Xavfsizlik',
            'content':
                'Parollar zamonaviy bir tomonlama shifrlash algoritmlari bilan himoyalangan — biz ham parolingizni matn ko\'rinishda ko\'ra olmaymiz. Ma\'lumotlar TLS 1.2+ orqali uzatiladi va AES-256 standartida shifrlangan disklarda saqlanadi. Server qoidalari har foydalanuvchini faqat o\'z ma\'lumotlariga cheklaydi — boshqa foydalanuvchilarning ma\'lumotlarini ko\'rib bo\'lmaydi. Internet orqali yuborilgan hech qanday ma\'lumot 100% xavfsiz emas, lekin biz sanoatdagi eng yaxshi xavfsizlik amaliyotlaridan foydalanamiz.'
          },
          {
            'title': '11. Uchinchi shaxslar',
            'content':
                'Ma\'lumotlaringizni hech qachon uchinchi shaxslarga sotmaymiz, ijaraga bermaymiz yoki marketing maqsadida bermaymiz. Faqat ishonchli texnik provayderlar (autentifikatsiya va bulutli saqlash xizmatlari) ma\'lumotlarni texnik jihatdan ko\'rishi mumkin — ular ham o\'z maxfiylik siyosatiga rioya qiladi va ma\'lumotlardan boshqa maqsadda foydalana olmaydi.'
          },
          {
            'title': '12. Bog\'lanish va o\'zgarishlar',
            'content':
                'Savollar, shikoyatlar, hisobni o\'chirish so\'rovi yoki maxfiylik bilan bog\'liq murojaatlar uchun: focusguard.app@gmail.com. Biz 7 ish kuni ichida javob beramiz. Ushbu shartlar vaqti-vaqti bilan yangilanishi mumkin — muhim o\'zgarishlar haqida ilova ichida xabar beriladi va ushbu sahifaning yuqorisida sana yangilanadi.'
          },
        ]
      },
      'errors': {
        'invalid_email': 'Email manzili noto\'g\'ri formatda.',
        'user_not_found': 'Bunday foydalanuvchi topilmadi.',
        'wrong_password': 'Email yoki parol noto\'g\'ri.',
        'email_already_in_use': 'Bu email allaqachon ro\'yxatdan o\'tgan.',
        'weak_password': 'Parol juda zaif (kamida 6 ta belgi bo\'lishi kerak).',
        'network_error': 'Internet aloqasi yo\'q yoki yomon.',
        'unknown_error':
            'Noma\'lum xatolik yuz berdi. Qaytadan urinib ko\'ring.',
      }
    },
    'ru': {
      'language': {
        'title': 'Выберите Язык',
        'subtitle': 'Выберите язык приложения, чтобы продолжить.',
        'continue': 'Продолжить',
      },
      'common': {
        'continue': 'Продолжить',
        'back': 'Назад',
        'save': 'Сохранить',
        'login': 'Войти в систему',
        'cancel': 'Отмена'
      },
      'onboarding': [
        {
          'title': 'Центр Глубокого Фокуса',
          'text':
              'Отключите социальные сети и ненужные уведомления, сосредоточьтесь только на важных целях.'
        },
        {
          'title': 'Блокировка Вредных Приложений',
          'text':
              'Блокируйте приложения, которые крадут ваше время, и направляйте свой день на продуктивную деятельность.'
        },
        {
          'title': 'Анализ Эффективности',
          'text':
              'Следите за тем, куда уходят ваши минуты, и анализируйте все свои результаты.'
        },
      ],
      'login': {
        'welcome': 'Добро Пожаловать.',
        'subtitle': 'Введите свои личные данные для входа в систему.',
        'email_hint': 'Username@gmail.com',
        'password_label': 'ПАРОЛЬ',
        'password_hint': '••••••••',
        'no_account': 'Нет аккаунта? ',
        'register': 'Зарегистрироваться',
        'terms': 'Условия использования и политика конфиденциальности',
        'forgot_password': 'Забыли пароль?',
        'forgot_password_title': 'Восстановление пароля',
        'forgot_password_desc':
            'Введите адрес электронной почты, указанный при регистрации. Мы отправим вам ссылку для сброса пароля.',
        'reset_link_sent':
            'Ссылка для сброса отправлена на ваш Gmail. Пожалуйста, проверьте почту.',
        'welcome_back': 'С возвращением, {name}!',
      },
      'register': {
        'title': 'Регистрация',
        'subtitle': 'Введите данные для создания нового аккаунта.',
        'name_label': 'ИМЯ И ФАМИЛИЯ',
        'name_hint': 'Введите ваше имя',
        'email_label': 'ПОЧТА',
        'password_label': 'ПАРОЛЬ',
        'confirm_password_label': 'ПОДТВЕРДИТЕ ПАРОЛЬ',
        'have_account': 'Уже есть аккаунт? ',
        'login_now': 'Войти',
        'welcome_new': 'Вы успешно зарегистрировались, {name}!',
        'check_spam':
            'Письмо с подтверждением отправлено. Если его нет в папке Входящие, проверьте папку Спам.',
      },
      'legal': {
        'title': 'Условия использования и Политика конфиденциальности',
        'close': 'Закрыть',
        'sections': [
          {
            'title': '1. О приложении',
            'content':
                'FocusGuard — приложение для повышения продуктивности и концентрации. Включает таймер Pomodoro, блокировку отвлекающих приложений, ежедневную статистику и напоминания.'
          },
          {
            'title': '2. Учётная запись и безопасность',
            'content':
                'Для использования приложения вы создаёте учётную запись через действительный email. Ваш email, пароль и личные данные хранятся в защищённом виде. Безопасность пароля и учётной записи лежит на вашей личной ответственности — не делитесь ими ни с кем. Если вы заметите несанкционированный доступ к учётной записи, немедленно смените пароль и свяжитесь с нами.'
          },
          {
            'title': '3. Правильное использование',
            'content':
                'Запрещается реверс-инжиниринг, декомпиляция или модификация исходного кода. Несанкционированный доступ к чужим учётным записям, фальсификация статистики, уровня или XP, использование автоматизированных средств (ботов, скриптов) — строго запрещено. Использование приложения в незаконных, вредоносных целях или способом, нарушающим права третьих лиц, недопустимо. Нарушение этих правил приводит к блокировке учётной записи.'
          },
          {
            'title': '4. Премиум-подписка',
            'content':
                'Приложение доступно для бесплатного использования. Премиум-подписка предоставляет дополнительные возможности: неограниченную облачную историю (у бесплатных пользователей сохраняется только за последние 7 дней), расширенные функции анализа и другие привилегированные сервисы, которые могут быть добавлены в будущем. Подписка приобретается через официальный магазин приложений (App Store или Google Play), откуда вы скачали приложение, и подчиняется его правилам. Запросы на возврат средств отправляются через этот магазин.'
          },
          {
            'title': '5. Какие данные собираются',
            'content':
                'Для учётной записи: email, пароль (зашифрованный), имя и дата регистрации. Для использования: уровень, XP, история фокуса, ежедневное время, выполненные сессии, планы и активности. Эти данные хранятся на защищённых облачных серверах и восстанавливаются при смене устройства. Список заблокированных приложений, иконки и настройки (язык, тема, переключатели уведомлений) остаются только на вашем устройстве и не отправляются на сервер.'
          },
          {
            'title': '6. Какие данные НЕ собираются',
            'content':
                'Мы никогда не собираем следующие данные: местоположение (GPS), номер телефона, контакты, SMS, историю звонков, фото, видео, аудиофайлы, записи микрофона или камеры, историю браузера и личные данные из других приложений. Рекламные идентификаторы и средства отслеживания отсутствуют. Наша единственная цель — дать вам продуктивный опыт фокуса.'
          },
          {
            'title': '7. Использование данных',
            'content':
                'Собранные данные используются только для основных функций приложения: сохранения учётной записи и аутентификации, отображения вашей статистики и уровня, отправки напоминаний в назначенное время, проверки статуса подписки, восстановления данных при смене устройства, исправления ошибок и улучшения качества. Ваши данные никогда не продаются в рекламных целях, не используются в маркетинге и ваш профиль не анализируется в коммерческих целях.'
          },
          {
            'title': '8. Требуемые разрешения',
            'content':
                'Для работы приложения запрашиваются некоторые системные разрешения: отправка уведомлений (напоминания и сообщения о завершении таймера), статистика использования приложений (для определения открытия заблокированного приложения), наложение окон (отображение экрана блокировки), точные будильники (для планов), управление режимом «Не беспокоить» (для функции Анти-Отвлечение) и работа в фоне (для непрерывной работы таймера и службы блокировки). Все разрешения используются только внутри приложения и не передаются на сервер. Любое разрешение можно отозвать в настройках устройства в любое время.'
          },
          {
            'title': '9. Права пользователя',
            'content':
                'В любое время вы можете воспользоваться следующими правами: просматривать свои данные, исправлять неверные или устаревшие данные, экспортировать свои данные и полностью удалить учётную запись. Запрос на удаление учётной записи выполняется в течение 30 дней — за это время можно восстановить запись, если она была удалена по ошибке. После 30 дней все данные удаляются безвозвратно. Для отправки запроса: focusguard.app@gmail.com.'
          },
          {
            'title': '10. Безопасность',
            'content':
                'Пароли защищены современными односторонними алгоритмами шифрования — даже мы не видим ваш пароль в открытом виде. Данные передаются через TLS 1.2+ и хранятся на дисках, зашифрованных по стандарту AES-256. Серверные правила ограничивают каждого пользователя только его собственными данными — данные других пользователей увидеть невозможно. Никакие данные, передаваемые через интернет, не являются 100% безопасными, но мы используем лучшие отраслевые практики безопасности.'
          },
          {
            'title': '11. Третьи стороны',
            'content':
                'Мы никогда не продаём, не сдаём в аренду и не передаём ваши данные третьим лицам в маркетинговых целях. Только надёжные технические провайдеры (службы аутентификации и облачного хранения) могут иметь технический доступ к данным — они также соблюдают свою политику конфиденциальности и не могут использовать данные в других целях.'
          },
          {
            'title': '12. Связь и изменения',
            'content':
                'Для вопросов, жалоб, запросов на удаление учётной записи или обращений, связанных с конфиденциальностью: focusguard.app@gmail.com. Мы отвечаем в течение 7 рабочих дней. Данные условия могут периодически обновляться — о важных изменениях будет сообщено внутри приложения, а в верхней части этой страницы будет обновлена дата.'
          },
        ]
      },
      'errors': {
        'invalid_email': 'Неверный формат email.',
        'user_not_found': 'Пользователь не найден.',
        'wrong_password': 'Неверный email или пароль.',
        'email_already_in_use': 'Этот email уже зарегистрирован.',
        'weak_password': 'Пароль слишком слабый (минимум 6 символов).',
        'network_error': 'Ошибка сети. Проверьте подключение.',
        'unknown_error': 'Произошла неизвестная ошибка. Попробуйте еще раз.',
      }
    },
    'en': {
      'language': {
        'title': 'Select Language',
        'subtitle': 'Choose app language to continue.',
        'continue': 'Continue',
      },
      'common': {
        'continue': 'Continue',
        'back': 'Back',
        'save': 'Save',
        'login': 'Log In',
        'cancel': 'Cancel'
      },
      'onboarding': [
        {
          'title': 'Deep Focus Center',
          'text':
              'Turn off social media and unnecessary notifications, focus only on important goals.'
        },
        {
          'title': 'Lock Distracting Apps',
          'text':
              'Block apps that steal your time and direct your day toward productive activities.'
        },
        {
          'title': 'Performance Analysis',
          'text':
              'Track where your minutes are going and analyze all your results.'
        },
      ],
      'login': {
        'welcome': 'Welcome Back.',
        'subtitle': 'Enter your personal details to log in to the system.',
        'email_hint': 'Username@gmail.com',
        'password_label': 'PASSWORD',
        'password_hint': '••••••••',
        'no_account': "Don't have an account? ",
        'register': 'Register Now',
        'terms': 'Terms of Use and Privacy Policy',
        'forgot_password': 'Forgot password?',
        'forgot_password_title': 'Reset Password',
        'forgot_password_desc':
            'Enter your registered email address. We will send you a link to reset your password.',
        'reset_link_sent':
            'Reset link has been sent to your Gmail. Please check your inbox.',
        'welcome_back': 'Welcome back, {name}!',
      },
      'register': {
        'title': 'Create Account',
        'subtitle': 'Enter details to create a new account.',
        'name_label': 'FULL NAME',
        'name_hint': 'Enter your full name',
        'email_label': 'EMAIL',
        'password_label': 'PASSWORD',
        'confirm_password_label': 'CONFIRM PASSWORD',
        'have_account': 'Already have an account? ',
        'login_now': 'Log In',
        'welcome_new': 'Successfully registered, {name}!',
        'check_spam':
            'Verification email sent. If not in Inbox, please check your Spam folder.',
      },
      'legal': {
        'title': 'Terms of Use and Privacy Policy',
        'close': 'Close',
        'sections': [
          {
            'title': '1. About the App',
            'content':
                'FocusGuard is a productivity app that helps you concentrate and stay focused. It includes a Pomodoro timer, distracting-app blocking, daily statistics, and reminders.'
          },
          {
            'title': '2. Account and Security',
            'content':
                'You create an account using a valid email address. Your email, password, and personal data are stored securely. Password and account security are your personal responsibility — do not share them with anyone. If you notice unauthorized access to your account, change the password immediately and contact us.'
          },
          {
            'title': '3. Acceptable Use',
            'content':
                'Reverse engineering, decompilation, or modification of the source code is prohibited. Unauthorized access to other accounts, falsifying statistics, level, or XP, and use of automated tools (bots, scripts) are strictly prohibited. The app may not be used for illegal, harmful, or rights-infringing purposes. Violating these rules results in account termination.'
          },
          {
            'title': '4. Premium Subscription',
            'content':
                'The app is free to use. Premium subscription provides additional features: unlimited cloud history (free users keep the last 7 days only), extended analytics, and other privileged services that may be added in the future. Subscription is purchased through the official app store (App Store or Google Play) you downloaded the app from and is subject to that store\'s rules. Refund requests are submitted through that store.'
          },
          {
            'title': '5. What Data We Collect',
            'content':
                'For your account: email, password (encrypted), name, and registration date. For app usage: level, XP, focus history, daily time, completed sessions, plans, and activities. This data is stored on secure cloud servers and restored if you change devices. The list of blocked apps, app icons, and settings (language, theme, notification toggles) remain only on your device and are not sent to any server.'
          },
          {
            'title': '6. What We Do NOT Collect',
            'content':
                'We never collect: location (GPS), phone number, contacts, SMS, call history, photos, videos, audio files, microphone or camera recordings, browser history, or personal data from other apps. There are no advertising identifiers or tracking tools. Our only goal is to provide you a productive focus experience.'
          },
          {
            'title': '7. How We Use the Data',
            'content':
                'Collected data is used only for the app\'s core functions: storing your account and authentication, showing your statistics and level, sending reminders at scheduled times, verifying subscription status, restoring data on device change, fixing errors and improving quality. Your data is never sold for advertising, used in marketing, or analyzed commercially.'
          },
          {
            'title': '8. Required Permissions',
            'content':
                'The app requests certain device permissions: notifications (reminders and timer-completed alerts), app usage stats (to detect when a blocked app opens), overlay window (to show the block screen), exact alarms (for plans), Do Not Disturb access (for the Anti-Distraction feature), and background execution (to keep the timer and blocking service running). All permissions are used only within the app and are not transmitted to any server. You can revoke any permission from device settings at any time.'
          },
          {
            'title': '9. User Rights',
            'content':
                'At any time, you may exercise the following rights: view your data, correct incorrect or outdated data, export your data, and fully delete your account. Account deletion requests are completed within 30 days — during this period, the account can be restored if deleted by mistake. After 30 days, all data is permanently erased. To submit a request: focusguard.app@gmail.com.'
          },
          {
            'title': '10. Security',
            'content':
                'Passwords are protected by modern one-way encryption algorithms — even we cannot see your password in plain text. Data is transmitted over TLS 1.2+ and stored on disks encrypted with AES-256. Server rules restrict each user to their own data — other users\' data cannot be viewed. No data transmitted over the internet is 100% secure, but we use the best industry security practices.'
          },
          {
            'title': '11. Third Parties',
            'content':
                'We never sell, rent, or share your data with third parties for marketing purposes. Only trusted technical providers (authentication and cloud storage services) may have technical access to the data — they also follow their own privacy policy and cannot use the data for any other purpose.'
          },
          {
            'title': '12. Contact and Changes',
            'content':
                'For questions, complaints, account deletion requests, or privacy-related inquiries: focusguard.app@gmail.com. We respond within 7 business days. These terms may be updated periodically — important changes will be announced inside the app and the date will be updated at the top of this page.'
          },
        ]
      },
      'errors': {
        'invalid_email': 'Invalid email format.',
        'user_not_found': 'User not found.',
        'wrong_password': 'Incorrect email or password.',
        'email_already_in_use': 'This email is already registered.',
        'weak_password': 'Password is too weak (min 6 characters).',
        'network_error': 'Network error. Please check your connection.',
        'unknown_error': 'An unknown error occurred. Please try again.',
      }
    }
  };

  // Helper to get translated string
  dynamic translate(String key) {
    List<String> keys = key.split('.');
    dynamic value = _translations[_currentLanguage] ?? _translations['en'];

    for (String k in keys) {
      if (value is Map && value.containsKey(k)) {
        value = value[k];
      } else if (value is List) {
        // Handle list indexing (e.g., onboarding.0.title)
        int? index = int.tryParse(k);
        if (index != null && index >= 0 && index < value.length) {
          value = value[index];
        } else {
          return key;
        }
      } else {
        return key; // Return the key itself if not found
      }
    }
    return value;
  }
}
