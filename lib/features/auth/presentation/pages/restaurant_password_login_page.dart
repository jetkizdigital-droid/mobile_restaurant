import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jetkiz_restaurant/core/push/restaurant_push_notification_service.dart';
import 'package:jetkiz_restaurant/core/session/restaurant_context.dart';
import 'package:jetkiz_restaurant/core/session/session_manager.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_api.dart';
import 'package:jetkiz_restaurant/features/navigation/presentation/pages/restaurant_shell_page.dart';

class RestaurantPasswordLoginPage extends StatefulWidget {
  const RestaurantPasswordLoginPage({
    super.key,
    this.initialPhone,
    this.languageCode = 'ru',
  });

  final String? initialPhone;
  final String languageCode;

  @override
  State<RestaurantPasswordLoginPage> createState() =>
      _RestaurantPasswordLoginPageState();
}

class _RestaurantPasswordLoginPageState
    extends State<RestaurantPasswordLoginPage> {
  final AuthApi _authApi = AuthApi();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _loading = false;
  bool _obscurePassword = true;

  bool get _isKazakh => widget.languageCode.trim().toLowerCase() == 'kk';
  String _t(String ru, String kk) => _isKazakh ? kk : ru;

  @override
  void initState() {
    super.initState();
    final raw = widget.initialPhone ?? '';
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && (digits.startsWith('7') || digits.startsWith('8'))) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) digits = digits.substring(digits.length - 10);
    _phoneController.text = digits;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String? _normalizedPhone() {
    final local = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (local.length != 10) return null;
    return '+7$local';
  }

  Future<void> _submit() async {
    if (_loading) return;

    final phone = _normalizedPhone();
    if (phone == null) {
      _showError(
        _t(
          'Введите 10 цифр номера после +7',
          '+7-ден кейін телефон нөмірінің 10 цифрын енгізіңіз',
        ),
      );
      return;
    }

    final password = _passwordController.text;
    if (password.isEmpty) {
      _showError(_t('Введите пароль', 'Құпиясөзді енгізіңіз'));
      return;
    }

    setState(() => _loading = true);

    try {
      await _authApi.loginRestaurantWithPassword(
        phone: phone,
        password: password,
      );

      final me = await _authApi.getMe();
      final restaurantId = resolveRestaurantIdFromMe(me)?.trim();
      if (restaurantId == null || restaurantId.isEmpty) {
        throw Exception(
          _t(
            'У аккаунта не найден ресторан',
            'Аккаунтқа тіркелген мейрамхана табылмады',
          ),
        );
      }

      SessionManager.restaurantId = restaurantId;

      try {
        await RestaurantPushNotificationService.instance.registerCurrentToken();
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('Restaurant password login push registration failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RestaurantShellPage()),
        (route) => false,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Restaurant password login failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      _showError(_cleanError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _cleanError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty
        ? _t('Не удалось войти', 'Кіру мүмкін болмады')
        : message;
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

  InputDecoration _inputDecoration({
    required String hintText,
    Widget? prefix,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF6F7D91)),
      prefixIcon: prefix,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF101827),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2A3950)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2A3950)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF65C044), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09111C),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_t('Вход по паролю', 'Құпиясөзбен кіру')),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
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
                    Text(
                      _t('Телефон', 'Телефон'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey('restaurant_password_phone_field'),
                      controller: _phoneController,
                      enabled: !_loading,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: const [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        hintText: '7000000000',
                        prefix: const Padding(
                          padding: EdgeInsets.fromLTRB(14, 14, 4, 14),
                          child: Text(
                            '+7',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      _t('Пароль', 'Құпиясөз'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey('restaurant_password_field'),
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      enabled: !_loading,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        hintText: _t('Введите пароль', 'Құпиясөзді енгізіңіз'),
                        suffixIcon: IconButton(
                          onPressed: _loading
                              ? null
                              : () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: const Color(0xFF8E9AAF),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        key: const ValueKey('restaurant_password_submit'),
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF489F2A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _t('Войти', 'Кіру'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _t(
                        'Вход по паролю доступен для аккаунтов с постоянным паролем JETKIZ.',
                        'Құпиясөзбен кіру JETKIZ тұрақты құпиясөзі бар аккаунттар үшін қолжетімді.',
                      ),
                      style: const TextStyle(
                        color: Color(0xFF95A0B3),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
