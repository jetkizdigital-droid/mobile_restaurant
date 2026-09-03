from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)


def replace_all_checked(text: str, old: str, new: str, expected: int, label: str) -> str:
    count = text.count(old)
    if count != expected:
        raise RuntimeError(f"{label}: expected {expected} matches, found {count}")
    return text.replace(old, new)


# 1) Registration compliance + channel-neutral OTP copy.
path = "lib/features/auth/presentation/pages/restaurant_auth_page.dart"
text = read(path)
text = replace_once(
    text,
    "import 'package:flutter/material.dart';\nimport 'package:jetkiz_restaurant/features/auth/data/auth_api.dart';",
    "import 'package:flutter/material.dart';\nimport 'package:jetkiz_restaurant/features/auth/data/auth_api.dart';\nimport 'package:url_launcher/url_launcher.dart';",
    "auth import",
)
text = replace_once(
    text,
    "  bool _isLoading = false;\n",
    "  bool _isLoading = false;\n  bool _registrationConsentAccepted = false;\n",
    "consent state",
)
text = replace_all_checked(
    text,
    "_t('Не удалось отправить SMS-код', 'SMS-код жіберілмеді')",
    "_t('Не удалось отправить код', 'Код жіберілмеді')",
    2,
    "OTP channel-neutral errors",
)
text = replace_once(
    text,
    """    if (nameRu.isEmpty || nameKk.isEmpty || address.isEmpty) {
      _showError(
        _t(
          'Заполните все обязательные поля',
          'Барлық міндетті өрістерді толтырыңыз',
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
""",
    """    if (nameRu.isEmpty || nameKk.isEmpty || address.isEmpty) {
      _showError(
        _t(
          'Заполните все обязательные поля',
          'Барлық міндетті өрістерді толтырыңыз',
        ),
      );
      return;
    }

    if (!_registrationConsentAccepted) {
      _showError(
        _t(
          'Подтвердите согласие с политикой конфиденциальности и обработкой персональных данных',
          'Құпиялылық саясатымен және дербес деректерді өңдеумен келісуді растаңыз',
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
""",
    "registration consent validation",
)
text = replace_once(
    text,
    """  void _showError(String message) {
""",
    """  Future<void> _openExternalDocument(String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showError(
        _t(
          'Не удалось открыть документ',
          'Құжатты ашу мүмкін болмады',
        ),
      );
    }
  }

  void _showError(String message) {
""",
    "external document helper",
)
text = replace_once(
    text,
    """        const SizedBox(height: 20),
        _GreenButton(
          text: _isLoading
              ? _t('Отправка...', 'Жіберілуде...')
              : _t('Продолжить', 'Жалғастыру'),
          onPressed: _isLoading ? null : _submitRegister,
        ),
""",
    """        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _registrationConsentAccepted,
              activeColor: const Color(0xFF489F2A),
              side: const BorderSide(color: Color(0xFF6F7D91)),
              onChanged: _isLoading
                  ? null
                  : (value) {
                      setState(() {
                        _registrationConsentAccepted = value ?? false;
                      });
                    },
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _t(
                        'Регистрируясь, вы соглашаетесь с правилами обработки данных JETKIZ.',
                        'Тіркелу арқылы JETKIZ деректерді өңдеу ережелерімен келісесіз.',
                      ),
                      style: const TextStyle(
                        color: Color(0xFF95A0B3),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 0,
                    children: [
                      TextButton(
                        onPressed: () => _openExternalDocument(
                          'https://jetkiz.asia/privacy',
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: const Color(0xFF65C044),
                        ),
                        child: Text(
                          _t(
                            'Политика конфиденциальности',
                            'Құпиялылық саясаты',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _openExternalDocument(
                          'https://jetkiz.asia/consent',
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: const Color(0xFF65C044),
                        ),
                        child: Text(
                          _t(
                            'Согласие на обработку данных',
                            'Деректерді өңдеуге келісім',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _GreenButton(
          text: _isLoading
              ? _t('Отправка...', 'Жіберілуде...')
              : _t('Продолжить', 'Жалғастыру'),
          onPressed: _isLoading ? null : _submitRegister,
        ),
""",
    "registration consent UI",
)
write(path, text)

# 2) OTP page: user-visible copy must not claim SMS while WhatsApp is primary.
path = "lib/features/auth/presentation/pages/restaurant_sms_page.dart"
text = read(path)
text = replace_once(
    text,
    "// SMS verification page for restaurant auth.",
    "// OTP verification page for restaurant auth.",
    "OTP comment",
)
text = replace_once(
    text,
    """                          'Введите код из SMS, отправленный на номер ${widget.phone}',
                          '${widget.phone} нөміріне SMS арқылы жіберілген кодты енгізіңіз',
""",
    """                          'Введите код подтверждения, отправленный на номер ${widget.phone}',
                          '${widget.phone} нөміріне жіберілген растау кодын енгізіңіз',
""",
    "OTP visible copy",
)
text = replace_once(
    text,
    "prefixIcon: Icons.sms_outlined,",
    "prefixIcon: Icons.verified_outlined,",
    "OTP icon",
)
write(path, text)

# 3) Push notifications: keep loud high-priority alerts without alarm/full-screen semantics.
path = "lib/core/push/restaurant_push_notification_service.dart"
text = read(path)
text = replace_once(
    text,
    """    await _requestPermission();
    await _initLocalNotifications();
""",
    """    await _initLocalNotifications();
""",
    "defer notification permission",
)
text = replace_once(
    text,
    """    if (accessToken == null || accessToken.trim().isEmpty) {
      if (kDebugMode) {
        debugPrint('RestaurantPush: skip token registration, no access token');
      }

      return;
    }

    final token = await getToken();
""",
    """    if (accessToken == null || accessToken.trim().isEmpty) {
      if (kDebugMode) {
        debugPrint('RestaurantPush: skip token registration, no access token');
      }

      return;
    }

    await _requestPermission();

    final token = await getToken();
""",
    "permission after auth",
)
text = replace_all_checked(
    text,
    "category: AndroidNotificationCategory.alarm,",
    "category: AndroidNotificationCategory.message,",
    2,
    "notification category",
)
text = replace_once(
    text,
    "          fullScreenIntent: true,\n",
    "",
    "remove full-screen intent",
)
write(path, text)

# 4) Account deletion compliance surface in the restaurant app.
path = "lib/features/support/presentation/pages/restaurant_support_page.dart"
text = read(path)
text = replace_once(
    text,
    """            _SupportAction(
              icon: Icons.delete_outline_rounded,
              title: 'Удаление аккаунта',
              subtitle: _requestingDeletion
                  ? 'Отправляем запрос…'
                  : 'Отправить официальный запрос в JETKIZ',
              enabled: !_requestingDeletion,
              onTap: _requestAccountDeletion,
            ),
""",
    """            _SupportAction(
              icon: Icons.info_outline_rounded,
              title: 'Как удаляются аккаунт и данные',
              subtitle: 'Открыть jetkiz.asia/account-deletion',
              onTap: () => _open(
                Uri.parse('https://jetkiz.asia/account-deletion'),
              ),
            ),
            _SupportAction(
              icon: Icons.delete_outline_rounded,
              title: 'Запросить удаление аккаунта',
              subtitle: _requestingDeletion
                  ? 'Отправляем запрос…'
                  : 'Отправить официальный запрос в JETKIZ',
              enabled: !_requestingDeletion,
              onTap: _requestAccountDeletion,
            ),
""",
    "account deletion web resource",
)
write(path, text)

# 5) Android 16 / Google Play target API requirement + disable Android backup for auth secrets.
path = "android/app/build.gradle.kts"
text = read(path)
text = replace_once(
    text,
    "    compileSdk = flutter.compileSdkVersion",
    "    compileSdk = 36",
    "compileSdk 36",
)
text = replace_once(
    text,
    "        targetSdk = flutter.targetSdkVersion",
    "        targetSdk = 36",
    "targetSdk 36",
)
write(path, text)

path = "android/app/src/main/AndroidManifest.xml"
text = read(path)
text = replace_once(
    text,
    """        android:label="Jetkiz Restaurant"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="false"
""",
    """        android:label="JETKIZ Restaurant"
        android:icon="@mipmap/ic_launcher"
        android:allowBackup="false"
        android:usesCleartextTraffic="false"
""",
    "manifest release hardening",
)
write(path, text)

# 6) Release CI: verify formatting, tests, Android policy and a signed release AAB.
ci = """name: Restaurant Flutter CI

on:
  workflow_dispatch:
  push:
    branches:
      - main
      - fix/restaurant-production-audit
      - fix/restaurant-google-play-production
  pull_request:
    paths:
      - 'lib/**'
      - 'test/**'
      - 'android/**'
      - 'ios/**'
      - 'pubspec.yaml'
      - 'pubspec.lock'
      - 'analysis_options.yaml'
      - '.github/workflows/flutter-ci.yml'

jobs:
  flutter:
    runs-on: ubuntu-latest
    timeout-minutes: 35

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Flutter version
        run: flutter --version

      - name: Install dependencies
        run: flutter pub get

      - name: Format check
        run: dart format --output=none --set-exit-if-changed lib test

      - name: Analyze
        run: flutter analyze --no-fatal-infos

      - name: Tests
        run: flutter test

      - name: Android release policy checks
        run: |
          grep -q 'compileSdk = 36' android/app/build.gradle.kts
          grep -q 'targetSdk = 36' android/app/build.gradle.kts
          ! grep -R 'fullScreenIntent: true' lib
          ! grep -R 'AndroidNotificationCategory.alarm' lib
          grep -q 'android:usesCleartextTraffic="false"' android/app/src/main/AndroidManifest.xml
          grep -q 'android:allowBackup="false"' android/app/src/main/AndroidManifest.xml

      - name: Build debug APK
        run: flutter build apk --debug

      - name: Prepare ephemeral CI release signing
        run: |
          keytool -genkeypair -v \
            -keystore "$RUNNER_TEMP/restaurant-ci-upload.jks" \
            -storepass ci-not-for-production \
            -keypass ci-not-for-production \
            -keyalg RSA \
            -keysize 2048 \
            -validity 3650 \
            -alias restaurant-ci \
            -dname "CN=JETKIZ CI,O=JETKIZ,C=KZ"
          cat > android/key.properties <<EOF
          storeFile=$RUNNER_TEMP/restaurant-ci-upload.jks
          storePassword=ci-not-for-production
          keyAlias=restaurant-ci
          keyPassword=ci-not-for-production
          EOF

      - name: Build release AAB
        run: flutter build appbundle --release
"""
write(".github/workflows/flutter-ci.yml", ci)

# 7) Minimal release-facing widget tests for registration consent and OTP copy.
test = r"""import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jetkiz_restaurant/features/auth/presentation/pages/restaurant_auth_page.dart';
import 'package:jetkiz_restaurant/features/auth/presentation/pages/restaurant_sms_page.dart';

void main() {
  testWidgets('restaurant registration exposes privacy consent controls', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RestaurantAuthPage()));

    await tester.tap(find.text('Регистрация'));
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('Политика конфиденциальности'), findsOneWidget);
    expect(find.text('Согласие на обработку данных'), findsOneWidget);
  });

  testWidgets('OTP screen uses channel-neutral confirmation copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RestaurantSmsPage(
          phone: '+7 700 000 00 00',
          isNewUser: false,
        ),
      ),
    );

    expect(find.textContaining('Введите код подтверждения'), findsOneWidget);
    expect(find.textContaining('SMS'), findsNothing);
  });
}
"""
write("test/release_compliance_test.dart", test)

print("Restaurant Google Play release fixes applied")
