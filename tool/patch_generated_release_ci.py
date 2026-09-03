from pathlib import Path

path = Path('.github/workflows/flutter-ci.yml')
text = path.read_text(encoding='utf-8')

old = """      - name: Format check
        run: dart format --output=none --set-exit-if-changed lib test

"""

new = """      - name: Verify Dart source encoding
        run: python3 tool/verify_dart_utf8.py

      - name: Format check release-critical Dart
        run: >-
          dart format --output=none --set-exit-if-changed
          lib/core/push/restaurant_push_notification_service.dart
          lib/features/auth/presentation/pages/restaurant_auth_page.dart
          lib/features/auth/presentation/pages/restaurant_sms_page.dart
          lib/features/orders/presentation/widgets/order_card.dart
          lib/features/support/presentation/pages/restaurant_support_page.dart
          test/release_compliance_test.dart

"""

if old not in text:
    raise SystemExit('Expected permanent CI format step not found')

path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('Permanent restaurant release CI hardened')
