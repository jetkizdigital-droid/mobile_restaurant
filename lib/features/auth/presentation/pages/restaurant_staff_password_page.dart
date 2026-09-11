import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jetkiz_restaurant/core/input/kazakhstan_phone_input.dart';
import 'package:jetkiz_restaurant/core/localization/app_locale_controller.dart';
import 'package:jetkiz_restaurant/core/navigation/app_page_route.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_api.dart';
import 'package:jetkiz_restaurant/features/navigation/presentation/pages/restaurant_shell_page.dart';
import 'package:jetkiz_restaurant/features/auth/presentation/pages/restaurant_sms_page.dart';

class RestaurantStaffPasswordPage extends StatefulWidget {
  const RestaurantStaffPasswordPage({
    super.key,
    this.initialLanguageCode = 'ru',
  });

  final String initialLanguageCode;

  @override
  State<RestaurantStaffPasswordPage> createState() =>
      _RestaurantStaffPasswordPageState();
}

class _RestaurantStaffPasswordPageState
    extends State<RestaurantStaffPasswordPage> {
  final AuthApi _auth = AuthApi();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _loading = false;
  bool _changeRequired = false;
  bool _obscurePassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String _normalizedPhone = '';
  String _temporaryPassword = '';

  String _t(String ru, String kk) => context.tr(ru, kk);

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _normalizePhone(String value) => normalizeKazakhstanPhone(value);

  bool _validPhone(String value) => _normalizePhone(value).isNotEmpty;

  String _friendlyError(Object error, String fallbackRu, String fallbackKk) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();

    if (raw.isEmpty ||
        raw.length > 220 ||
        lower.contains('dioexception') ||
        lower.contains('socketexception') ||
        lower.contains('exception') ||
        lower.contains('backend') ||
        lower.contains('api') ||
        lower.contains('endpoint') ||
        lower.contains('http ') ||
        lower.contains('status code') ||
        lower.contains('connection')) {
      return _t(fallbackRu, fallbackKk);
    }

    return raw;
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

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (!_validPhone(phone)) {
      _showError(
        _t(
          'Введите корректный номер телефона.',
          'Телефон нөмірін дұрыс енгізіңіз.',
        ),
      );
      return;
    }
    if (password.isEmpty) {
      _showError(_t('Введите пароль.', 'Құпиясөзді енгізіңіз.'));
      return;
    }

    setState(() => _loading = true);
    try {
      final normalizedPhone = _normalizePhone(phone);
      final result = await _auth.loginRestaurantWithPassword(
        phone: normalizedPhone,
        password: password,
      );

      if (!mounted) return;
      if (result['passwordChangeRequired'] == true) {
        setState(() {
          _normalizedPhone = normalizedPhone;
          _temporaryPassword = password;
          _changeRequired = true;
          _passwordController.clear();
        });
        return;
      }

      _openShell();
    } catch (error) {
      _showError(
        _friendlyError(
          error,
          'Не удалось войти. Проверьте телефон и пароль.',
          'Кіру мүмкін болмады. Телефон мен құпиясөзді тексеріңіз.',
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginBySms() async {
    final phone = _phoneController.text.trim();
    if (!_validPhone(phone)) {
      _showError(
        _t(
          'Введите корректный номер телефона.',
          'Телефон нөмірін дұрыс енгізіңіз.',
        ),
      );
      return;
    }
    if (_loading) return;

    setState(() => _loading = true);
    try {
      final normalizedPhone = _normalizePhone(phone);
      await _auth.requestCode(phone: normalizedPhone);
      if (!mounted) return;
      await Navigator.of(context).push(
        AppPageRoute<void>(
          page: RestaurantSmsPage(
            phone: normalizedPhone,
            isNewUser: false,
            languageCode: AppLocaleController.instance.languageCode,
          ),
        ),
      );
    } catch (error) {
      _showError(
        _friendlyError(
          error,
          'Не удалось отправить код. Попробуйте позже.',
          'Кодты жіберу мүмкін болмады. Кейінірек қайталап көріңіз.',
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changePassword() async {
    final newPassword = _newPasswordController.text;
    final confirmation = _confirmPasswordController.text;

    if (newPassword.length < 8) {
      _showError(
        _t(
          'Новый пароль должен содержать не менее 8 символов.',
          'Жаңа құпиясөз кемінде 8 таңбадан тұруы керек.',
        ),
      );
      return;
    }
    if (newPassword == _temporaryPassword) {
      _showError(
        _t(
          'Придумайте новый пароль, отличный от временного.',
          'Уақытша құпиясөзден өзгеше жаңа құпиясөз ойлап табыңыз.',
        ),
      );
      return;
    }
    if (newPassword != confirmation) {
      _showError(
        _t('Пароли не совпадают.', 'Құпиясөздер сәйкес келмейді.'),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.changeRestaurantTemporaryPassword(
        phone: _normalizedPhone,
        currentPassword: _temporaryPassword,
        newPassword: newPassword,
      );
      if (!mounted) return;
      _openShell();
    } catch (error) {
      _showError(
        _friendlyError(
          error,
          'Не удалось изменить пароль. Попробуйте ещё раз.',
          'Құпиясөзді өзгерту мүмкін болмады. Қайта көріңіз.',
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openShell() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      AppPageRoute<void>(page: const RestaurantShellPage()),
      (route) => false,
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
        title: Text(
          _changeRequired
              ? _t('Создайте пароль', 'Құпиясөз жасаңыз')
              : _t('Вход сотрудника', 'Қызметкердің кіруі'),
        ),
        actions: [
          TextButton(
            onPressed: _loading ? null : AppLocaleController.instance.toggle,
            child: Text(
              context.isKazakh ? 'RU' : 'ҚАЗ',
              style: const TextStyle(
                color: Color(0xFF65C044),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _changeRequired ? _buildChangePassword() : _buildLogin(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('Кабинет сотрудника', 'Қызметкер кабинеті'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _t(
            'Введите телефон и пароль, который выдал владелец ресторана.',
            'Мейрамхана иесі берген телефон нөмірі мен құпиясөзді енгізіңіз.',
          ),
          style: const TextStyle(color: Color(0xFF95A0B3), height: 1.45),
        ),
        const SizedBox(height: 28),
        _field(
          controller: _phoneController,
          label: _t('Телефон', 'Телефон'),
          hint: '777 000 00 00',
          keyboardType: TextInputType.phone,
          icon: Icons.phone_outlined,
          prefixText: '+7 ',
          inputFormatters: const [KazakhstanPhoneInputFormatter()],
        ),
        const SizedBox(height: 16),
        _field(
          controller: _passwordController,
          label: _t('Пароль', 'Құпиясөз'),
          hint: _t('Введите пароль', 'Құпиясөзді енгізіңіз'),
          obscureText: _obscurePassword,
          icon: Icons.lock_outline_rounded,
          suffix: IconButton(
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: const Color(0xFF95A0B3),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _submitButton(
          label: _loading ? _t('Вход...', 'Кіру...') : _t('Войти', 'Кіру'),
          onPressed: _loading ? null : _login,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _loading ? null : _loginBySms,
            icon: const Icon(Icons.sms_outlined),
            label: Text(
              _t(
                'Забыли пароль? Войти по SMS',
                'Құпиясөзді ұмыттыңыз ба? SMS арқылы кіру',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChangePassword() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.verified_user_outlined,
          color: Color(0xFF65C044),
          size: 48,
        ),
        const SizedBox(height: 18),
        Text(
          _t('Задайте личный пароль', 'Жеке құпиясөз орнатыңыз'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _t(
            'Временный пароль принят. Для безопасности создайте свой пароль. До этого кабинет не откроется.',
            'Уақытша құпиясөз қабылданды. Қауіпсіздік үшін өз құпиясөзіңізді жасаңыз. Оған дейін кабинет ашылмайды.',
          ),
          style: const TextStyle(color: Color(0xFF95A0B3), height: 1.45),
        ),
        const SizedBox(height: 28),
        _field(
          controller: _newPasswordController,
          label: _t('Новый пароль', 'Жаңа құпиясөз'),
          hint: _t('Минимум 8 символов', 'Кемінде 8 таңба'),
          obscureText: _obscureNewPassword,
          icon: Icons.lock_reset_rounded,
          suffix: IconButton(
            onPressed: () =>
                setState(() => _obscureNewPassword = !_obscureNewPassword),
            icon: Icon(
              _obscureNewPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: const Color(0xFF95A0B3),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _field(
          controller: _confirmPasswordController,
          label: _t('Повторите пароль', 'Құпиясөзді қайталаңыз'),
          hint: _t('Повторите новый пароль', 'Жаңа құпиясөзді қайталаңыз'),
          obscureText: _obscureConfirmPassword,
          icon: Icons.lock_outline_rounded,
          suffix: IconButton(
            onPressed: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword,
            ),
            icon: Icon(
              _obscureConfirmPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: const Color(0xFF95A0B3),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _submitButton(
          label: _loading
              ? _t('Сохранение...', 'Сақталуда...')
              : _t('Сохранить и войти', 'Сақтап, кіру'),
          onPressed: _loading ? null : _changePassword,
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
    String? prefixText,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          obscureText: obscureText,
          enabled: !_loading,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF667085)),
            prefixIcon: Icon(icon, color: const Color(0xFF95A0B3)),
            prefixText: prefixText,
            prefixStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            suffixIcon: suffix,
            filled: true,
            fillColor: const Color(0xFF111B2B),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF26374F)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF26374F)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF65C044)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _submitButton({
    required String label,
    required Future<void> Function()? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF65C044),
          foregroundColor: const Color(0xFF061004),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
