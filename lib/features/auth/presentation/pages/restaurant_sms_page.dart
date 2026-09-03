// JETKIZ RESTAURANT APP
// OTP verification page for restaurant auth.
//
// FLOW:
// 1. request code on auth screen
// 2. open this page
// 3. verify code
// 4. if isNewUser == true -> backend finishes registration
// 5. if isNewUser == false -> normal login
// 6. after successful login/register -> register FCM token for restaurant app

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/push/restaurant_push_notification_service.dart';
import 'package:jetkiz_restaurant/core/session/restaurant_context.dart';
import 'package:jetkiz_restaurant/core/session/session_manager.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_api.dart';
import 'package:jetkiz_restaurant/features/navigation/presentation/pages/restaurant_shell_page.dart';

class RestaurantSmsPage extends StatefulWidget {
  final String phone;
  final bool isNewUser;
  final Map<String, dynamic>? registerData;
  final String languageCode;

  const RestaurantSmsPage({
    super.key,
    required this.phone,
    required this.isNewUser,
    this.registerData,
    this.languageCode = 'ru',
  });

  @override
  State<RestaurantSmsPage> createState() => _RestaurantSmsPageState();
}

class _RestaurantSmsPageState extends State<RestaurantSmsPage> {
  final AuthApi _authApi = AuthApi();
  final TextEditingController _codeController = TextEditingController();

  bool _isLoading = false;
  bool _isResending = false;

  bool get _isKazakh => widget.languageCode.trim().toLowerCase() == 'kk';

  String _t(String ru, String kk) => _isKazakh ? kk : ru;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      _showError(_t('Введите код', 'Кодты енгізіңіз'));
      return;
    }

    if (_isLoading) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final normalizedPhone = widget.phone.trim();
      final isNewUser = widget.isNewUser;
      final registerData = widget.registerData;

      if (isNewUser && registerData != null) {
        await _authApi.registerRestaurant(
          phone: normalizedPhone,
          code: code,
          nameRu: (registerData['nameRu'] ?? '').toString().trim(),
          nameKk: (registerData['nameKk'] ?? '').toString().trim(),
          address: (registerData['address'] ?? '').toString().trim(),
          workingHoursFrom: (registerData['workingHoursFrom'] ?? '')
              .toString()
              .trim(),
          workingHoursTo: (registerData['workingHoursTo'] ?? '')
              .toString()
              .trim(),
        );
      } else {
        await _authApi.verifyCode(phone: normalizedPhone, code: code);
      }

      final me = await _authApi.getMe();
      final restaurantId = resolveRestaurantIdFromMe(me)?.trim();

      if (restaurantId == null || restaurantId.isEmpty) {
        _showError(
          _t(
            'У аккаунта не найден ресторан',
            'Аккаунтқа тіркелген мейрамхана табылмады',
          ),
        );
        return;
      }

      SessionManager.restaurantId = restaurantId;

      await _registerPushTokenSafely();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RestaurantShellPage()),
        (route) => false,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('RestaurantSmsPage.verifyCode failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      _showError(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _registerPushTokenSafely() async {
    try {
      await RestaurantPushNotificationService.instance.registerCurrentToken();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Restaurant push token registration failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      // Push registration must not block successful authentication.
    }
  }

  Future<void> _resendCode() async {
    if (_isResending) {
      return;
    }

    setState(() => _isResending = true);

    try {
      await _authApi.requestCode(phone: widget.phone.trim());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Код отправлен повторно', 'Код қайта жіберілді')),
        ),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('RestaurantSmsPage.resendCode failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      _showError(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  String _cleanError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();

    if (message.isEmpty) {
      return _t('Произошла ошибка', 'Қате орын алды');
    }

    return message;
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB3261E),
          content: Text(
            message.trim().isEmpty
                ? _t('Произошла ошибка', 'Қате орын алды')
                : message.trim(),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundTop = Color(0xFF0E1A2C);
    const backgroundBottom = Color(0xFF08101C);
    const panelColor = Color(0xFF121B2C);
    const borderColor = Color(0xFF22324A);
    const textMuted = Color(0xFF95A0B3);

    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundTop, Color(0xFF0B1524), backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: panelColor.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t('Подтверждение', 'Растау'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t(
                          'Введите код подтверждения, отправленный на номер ${widget.phone}',
                          '${widget.phone} нөміріне жіберілген растау кодын енгізіңіз',
                        ),
                        style: const TextStyle(
                          color: textMuted,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _FieldLabel(_t('Код подтверждения', 'Растау коды')),
                      const SizedBox(height: 8),
                      _DarkTextField(
                        controller: _codeController,
                        hintText: _t('Введите код', 'Кодты енгізіңіз'),
                        prefixIcon: Icons.verified_outlined,
                        keyboardType: TextInputType.number,
                        enabled: !_isLoading,
                        onSubmitted: (_) {
                          if (!_isLoading) {
                            _verifyCode();
                          }
                        },
                      ),
                      const SizedBox(height: 18),
                      _GreenButton(
                        text: _isLoading
                            ? _t('Проверка...', 'Тексерілуде...')
                            : _t('Подтвердить', 'Растау'),
                        onPressed: _isLoading ? null : _verifyCode,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _isLoading || _isResending
                              ? null
                              : _resendCode,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF2A3950)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            _isResending
                                ? _t('Отправка...', 'Жіберілуде...')
                                : _t(
                                    'Отправить код повторно',
                                    'Кодты қайта жіберу',
                                  ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _t(
                          'Если код не пришёл, запросите его ещё раз.',
                          'Код келмесе, оны қайта сұратыңыз.',
                        ),
                        style: const TextStyle(
                          color: textMuted,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  const _DarkTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType,
    this.enabled = true,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3950)),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.done,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF6F7D91), fontSize: 14),
          prefixIcon: Icon(
            prefixIcon,
            color: const Color(0xFF8E9AAF),
            size: 20,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

class _GreenButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const _GreenButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF489F2A),
          disabledBackgroundColor: const Color(
            0xFF489F2A,
          ).withValues(alpha: 0.6),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
