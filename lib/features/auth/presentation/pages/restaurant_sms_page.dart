// JETKIZ RESTAURANT APP
// SMS verification page for restaurant auth.
//
// FLOW:
// 1. request code on auth screen
// 2. open this page
// 3. verify code
// 4. if isNewUser == true -> backend finishes registration
// 5. if isNewUser == false -> normal login

import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/session/session_manager.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_api.dart';
import 'package:jetkiz_restaurant/features/navigation/presentation/pages/restaurant_shell_page.dart';

class RestaurantSmsPage extends StatefulWidget {
  final String phone;
  final bool isNewUser;
  final Map<String, dynamic>? registerData;

  const RestaurantSmsPage({
    super.key,
    required this.phone,
    required this.isNewUser,
    this.registerData,
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

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    debugPrint('[_verifyCode] code: $code');

    if (code.isEmpty) {
      _showError('Введите код');
      debugPrint('[_verifyCode] код пустой');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final normalizedPhone = widget.phone;
      final isNewUser = widget.isNewUser;
      final registerData = widget.registerData;

      debugPrint(
        '[_verifyCode] normalizedPhone: $normalizedPhone, isNewUser: $isNewUser',
      );

      if (isNewUser && registerData != null) {
        debugPrint('[_verifyCode] Registering restaurant...');
        await _authApi.registerRestaurant(
          phone: normalizedPhone,
          code: code,
          nameRu: (registerData['nameRu'] ?? '').toString(),
          nameKk: (registerData['nameKk'] ?? '').toString(),
          address: (registerData['address'] ?? '').toString(),
          workingHoursFrom: (registerData['workingHoursFrom'] ?? '').toString(),
          workingHoursTo: (registerData['workingHoursTo'] ?? '').toString(),
        );
        debugPrint('[_verifyCode] registerRestaurant success');
      } else {
        debugPrint('[_verifyCode] Verifying code...');
        await _authApi.verifyCode(
          phone: normalizedPhone,
          code: code,
        );
        debugPrint('[_verifyCode] verifyCode success');
      }

      final me = await _authApi.getMe();
      debugPrint('ME RESPONSE: $me');

      final restaurantId = me['restaurantId']?.toString();
      debugPrint('restaurantId: $restaurantId');

      if (restaurantId == null || restaurantId.isEmpty) {
        debugPrint('restaurantId is NULL/EMPTY > backend не вернул привязку');
        _showError('У аккаунта не найден ресторан');
        return;
      }

      SessionManager.restaurantId = restaurantId;

      if (!mounted) return;

      debugPrint('[_verifyCode] Navigation to RestaurantShellPage');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RestaurantShellPage()),
        (route) => false,
      );
    } catch (e, st) {
      debugPrint('[_verifyCode] ERROR: $e');
      debugPrintStack(stackTrace: st);
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);

    try {
      await _authApi.requestCode(phone: widget.phone);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Код отправлен повторно'),
        ),
      );
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFB3261E),
        content: Text(message),
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
            colors: [
              backgroundTop,
              Color(0xFF0B1524),
              backgroundBottom,
            ],
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
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Подтверждение',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Введите код из SMS, отправленный на номер ${widget.phone}',
                        style: const TextStyle(
                          color: textMuted,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _FieldLabel('Код подтверждения'),
                      const SizedBox(height: 8),
                      _DarkTextField(
                        controller: _codeController,
                        hintText: 'Введите код',
                        prefixIcon: Icons.sms_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 18),
                      _GreenButton(
                        text: _isLoading ? 'Проверка...' : 'Подтвердить',
                        onPressed: _isLoading ? null : _verifyCode,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _isResending ? null : _resendCode,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF2A3950)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            _isResending
                                ? 'Отправка...'
                                : 'Отправить код повторно',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Если код не пришёл, попробуйте запросить его ещё раз.',
                        style: TextStyle(
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

  const _DarkTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType,
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
        keyboardType: keyboardType,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF6F7D91),
            fontSize: 14,
          ),
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

  const _GreenButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF489F2A),
          disabledBackgroundColor: const Color(0xFF489F2A).withValues(alpha: 0.6),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}