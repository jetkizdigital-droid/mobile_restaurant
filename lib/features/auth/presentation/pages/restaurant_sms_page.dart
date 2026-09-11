import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/localization/app_locale_controller.dart';
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

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String _safeError(Object error, String ru, String kk) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    if (raw.isEmpty ||
        raw.length > 180 ||
        lower.contains('dio') ||
        lower.contains('socket') ||
        lower.contains('exception') ||
        lower.contains('backend') ||
        lower.contains('endpoint') ||
        lower.contains('status code') ||
        lower.contains('http')) {
      return context.tr(ru, kk);
    }
    return raw;
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showError(context.tr('Введите код', 'Кодты енгізіңіз'));
      return;
    }
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final normalizedPhone = widget.phone.trim();
      final registerData = widget.registerData;

      if (widget.isNewUser && registerData != null) {
        await _authApi.registerRestaurant(
          phone: normalizedPhone,
          code: code,
          nameRu: (registerData['nameRu'] ?? '').toString().trim(),
          nameKk: (registerData['nameKk'] ?? '').toString().trim(),
          address: (registerData['address'] ?? '').toString().trim(),
          workingHoursFrom:
              (registerData['workingHoursFrom'] ?? '').toString().trim(),
          workingHoursTo:
              (registerData['workingHoursTo'] ?? '').toString().trim(),
        );
      } else {
        await _authApi.verifyCode(phone: normalizedPhone, code: code);
      }

      final me = await _authApi.getMe();
      final restaurantId = resolveRestaurantIdFromMe(me)?.trim();
      if (restaurantId == null || restaurantId.isEmpty) {
        _showError(
          context.tr(
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
        MaterialPageRoute<void>(builder: (_) => const RestaurantShellPage()),
        (route) => false,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('RestaurantSmsPage.verifyCode failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      _showError(
        _safeError(
          error,
          'Не удалось подтвердить код. Проверьте код и попробуйте снова.',
          'Кодты растау мүмкін болмады. Кодты тексеріп, қайта көріңіз.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    }
  }

  Future<void> _resendCode() async {
    if (_isResending) return;
    setState(() => _isResending = true);

    try {
      await _authApi.requestCode(phone: widget.phone.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Код отправлен повторно', 'Код қайта жіберілді'),
          ),
        ),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('RestaurantSmsPage.resendCode failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      _showError(
        _safeError(
          error,
          'Не удалось отправить код повторно. Попробуйте позже.',
          'Кодты қайта жіберу мүмкін болмады. Кейінірек қайталап көріңіз.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB3261E),
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E1A2C), Color(0xFF0B1524), Color(0xFF08101C)],
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
                    color: const Color(0xFF121B2C),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF22324A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                          const Spacer(),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : AppLocaleController.instance.toggle,
                            child: Text(
                              context.isKazakh ? 'RU' : 'ҚАЗ',
                              style: const TextStyle(
                                color: Color(0xFF65C044),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('Подтверждение', 'Растау'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr(
                          'Введите код подтверждения, отправленный на номер ${widget.phone}',
                          '${widget.phone} нөміріне жіберілген растау кодын енгізіңіз',
                        ),
                        style: const TextStyle(
                          color: Color(0xFF95A0B3),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _FieldLabel(
                        context.tr('Код подтверждения', 'Растау коды'),
                      ),
                      const SizedBox(height: 8),
                      _DarkTextField(
                        controller: _codeController,
                        hintText: context.tr('Введите код', 'Кодты енгізіңіз'),
                        prefixIcon: Icons.verified_outlined,
                        keyboardType: TextInputType.number,
                        enabled: !_isLoading,
                        onSubmitted: (_) {
                          if (!_isLoading) _verifyCode();
                        },
                      ),
                      const SizedBox(height: 18),
                      _GreenButton(
                        text: _isLoading
                            ? context.tr('Проверка...', 'Тексерілуде...')
                            : context.tr('Подтвердить', 'Растау'),
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
                                ? context.tr('Отправка...', 'Жіберілуде...')
                                : context.tr(
                                    'Отправить код повторно',
                                    'Кодты қайта жіберу',
                                  ),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        context.tr(
                          'Если код не пришёл, запросите его ещё раз.',
                          'Код келмесе, оны қайта сұратыңыз.',
                        ),
                        style: const TextStyle(
                          color: Color(0xFF95A0B3),
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
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  const _DarkTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType,
    this.enabled = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

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
          hintStyle: const TextStyle(color: Color(0xFF6F7D91)),
          prefixIcon: Icon(prefixIcon, color: const Color(0xFF8E9AAF)),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

class _GreenButton extends StatelessWidget {
  const _GreenButton({required this.text, required this.onPressed});

  final String text;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF489F2A),
          disabledBackgroundColor:
              const Color(0xFF489F2A).withValues(alpha: 0.6),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
