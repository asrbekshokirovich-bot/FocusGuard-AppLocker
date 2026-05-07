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
        'title': 'Huquqiy Ma\'lumotlar',
        'close': 'Yopish',
        'sections': [
          {
            'title': '1. Foydalanish Shartlari',
            'content':
                'FocusGuard ilovasidan foydalanish orqali siz ushbu shartlarga to\'liq rozilik bildirasiz. Ilova mahsuldorlikni oshirish va diqqatni jamlashga yordam berish uchun yaratilgan.'
          },
          {
            'title': '2. Maxfiylik Siyosati',
            'content':
                'Biz sizning maxfiyligingizni qadrlaymiz. FocusGuard faqat ilovaning asosiy funksiyalari uchun zarur bo\'lgan minimal statistik ma’lumotlarni to’playdi.'
          },
          {
            'title': '3. Foydalanuvchi Mas’uliyati',
            'content':
                'Siz o’z hisobingiz va parolingiz xavfsizligi uchun shaxsan javobgarsiz. Hisobingizdan ruxsatsiz foydalanilganini sezsangiz, darhol bizga xabar berishingiz kerak.'
          },
          {
            'title': '4. Ma’lumotlar Xavfsizligi',
            'content':
                'Barcha shaxsiy va statistik ma’lumotlar sanoat standartlariga muvofiq AES-256 shifrlash usullari bilan himoyalangan.'
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
        'title': 'Юридическая Информация',
        'close': 'Закрыть',
        'sections': [
          {
            'title': '1. Условия Использования',
            'content':
                'Используя приложение FocusGuard, вы полностью соглашаетесь с этими условиями. Приложение создано для повышения продуктивности и улучшения концентрации.'
          },
          {
            'title': '2. Политика Конфиденциальности',
            'content':
                'Мы ценим вашу конфиденциальность. FocusGuard собирает только минимальные статистические данные, необходимые для основных функций приложения.'
          },
          {
            'title': '3. Ответственность Пользователя',
            'content':
                'Вы несете личную ответственность за безопасность своей учетной записи и пароля. Если вы заметите несанкционированное использование вашего аккауnta, немедленно сообщите нам.'
          },
          {
            'title': '4. Безопасность Данных',
            'content':
                'Все личные и статистические данные защищены методами шифрования AES-256 в соответствии с отраслевыми стандартами.'
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
        'title': 'Legal Information',
        'close': 'Close',
        'sections': [
          {
            'title': '1. Terms of Use',
            'content':
                'By using the FocusGuard app, you fully agree to these terms. The app is designed to increase productivity and help with concentration.'
          },
          {
            'title': '2. Privacy Policy',
            'content':
                'We value your privacy. FocusGuard only collects minimal statistical data necessary for the main functions of the app.'
          },
          {
            'title': '3. User Responsibility',
            'content':
                'You are personally responsible for the security of your account and password. If you notice unauthorized use of your account, you must inform us immediately.'
          },
          {
            'title': '4. Data Security',
            'content':
                'All personal and statistical data are protected by AES-256 encryption methods in accordance with industry standards.'
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
