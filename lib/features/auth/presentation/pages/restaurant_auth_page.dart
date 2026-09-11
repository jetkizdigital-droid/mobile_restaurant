import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jetkiz_restaurant/core/input/kazakhstan_phone_input.dart';
import 'package:jetkiz_restaurant/core/localization/app_locale_controller.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_api.dart';
import 'package:url_launcher/url_launcher.dart';

import 'restaurant_sms_page.dart';

enum RestaurantAuthTab { login, register }

class RestaurantAuthPage extends StatefulWidget {
  const RestaurantAuthPage({super.key});

  @override
  State<RestaurantAuthPage> createState() => _RestaurantAuthPageState();
}

class _RestaurantAuthPageState extends State<RestaurantAuthPage> {
  final AuthApi _authApi = AuthApi();
  final TextEditingController _loginPhoneController = TextEditingController();
  final TextEditingController _registerPhoneController = TextEditingController();
  final TextEditingController _nameRuController = TextEditingController();
  final TextEditingController _nameKkController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  RestaurantAuthTab _tab = RestaurantAuthTab.login;
  bool _isLoading = false;
  bool _registrationConsentAccepted = false;
  TimeOfDay _openTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 22, minute: 0);

  @override
  void dispose() {
    _loginPhoneController.dispose();
    _registerPhoneController.dispose();
    _nameRuController.dispose();
    _nameKkController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String _normalizePhone(String value) => normalizeKazakhstanPhone(value);

  bool _isValidPhone(String value) => _normalizePhone(value).isNotEmpty;

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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

  Future<void> _pickTime(bool opening) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: opening ? _openTime : _closeTime,
      helpText: context.tr('Выберите время', 'Уақытты таңдаңыз'),
      cancelText: context.tr('Отмена', 'Бас тарту'),
      confirmText: context.tr('Готово', 'Дайын'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF489F2A),
            surface: Color(0xFF121826),
            onPrimary: Colors.white,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (opening) {
        _openTime = picked;
      } else {
        _closeTime = picked;
      }
    });
  }

  Future<void> _submitLogin() async {
    final phone = _loginPhoneController.text.trim();
    if (!_isValidPhone(phone)) {
      _showError(
        context.tr(
          'Введите корректный номер телефона',
          'Телефон нөмірін дұрыс енгізіңіз',
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final normalizedPhone = _normalizePhone(phone);
      await _authApi.requestCode(phone: normalizedPhone);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RestaurantSmsPage(
            phone: normalizedPhone,
            isNewUser: false,
            registerData: null,
            languageCode: AppLocaleController.instance.languageCode,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(
        _safeError(
          error,
          'Не удалось отправить код. Проверьте интернет и повторите.',
          'Кодты жіберу мүмкін болмады. Интернетті тексеріп, қайталаңыз.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitRegister() async {
    final phone = _registerPhoneController.text.trim();
    final nameRu = _nameRuController.text.trim();
    final nameKk = _nameKkController.text.trim();
    final address = _addressController.text.trim();

    if (!_isValidPhone(phone)) {
      _showError(
        context.tr(
          'Введите корректный номер телефона',
          'Телефон нөмірін дұрыс енгізіңіз',
        ),
      );
      return;
    }
    if (nameRu.isEmpty || nameKk.isEmpty || address.isEmpty) {
      _showError(
        context.tr(
          'Заполните все обязательные поля',
          'Барлық міндетті өрістерді толтырыңыз',
        ),
      );
      return;
    }
    if (!_registrationConsentAccepted) {
      _showError(
        context.tr(
          'Подтвердите согласие с политикой конфиденциальности и обработкой персональных данных',
          'Құпиялылық саясатымен және дербес деректерді өңдеумен келісуді растаңыз',
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final normalizedPhone = _normalizePhone(phone);
      await _authApi.requestCode(phone: normalizedPhone);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RestaurantSmsPage(
            phone: normalizedPhone,
            isNewUser: true,
            languageCode: AppLocaleController.instance.languageCode,
            registerData: {
              'nameRu': nameRu,
              'nameKk': nameKk,
              'address': address,
              'workingHoursFrom': _formatTime(_openTime),
              'workingHoursTo': _formatTime(_closeTime),
            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(
        _safeError(
          error,
          'Не удалось отправить код. Проверьте интернет и повторите.',
          'Кодты жіберу мүмкін болмады. Интернетті тексеріп, қайталаңыз.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openExternalDocument(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _showError(
        context.tr(
          'Не удалось открыть документ',
          'Құжатты ашу мүмкін болмады',
        ),
      );
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
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: _LanguageSwitcher(
                        kazakh: context.isKazakh,
                        onToggle: AppLocaleController.instance.toggle,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: const Color(0xFF489F2A),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'jetkiz',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'JETKIZ Restaurant',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(
                        'Доступ к кабинету ресторана',
                        'Мейрамхана кабинетіне кіру',
                      ),
                      style: const TextStyle(
                        color: Color(0xFF95A0B3),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _AuthTabs(
                      tab: _tab,
                      onChanged: (tab) => setState(() => _tab = tab),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121B2C),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF22324A)),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _tab == RestaurantAuthTab.login
                            ? _buildLoginForm()
                            : _buildRegisterForm(),
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

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey('login_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('С возвращением', 'Қайта қош келдіңіз'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('Введите номер телефона', 'Телефон нөмірін енгізіңіз'),
          style: const TextStyle(color: Color(0xFF95A0B3), fontSize: 13),
        ),
        const SizedBox(height: 22),
        _FieldLabel(context.tr('Телефон', 'Телефон')),
        const SizedBox(height: 8),
        _DarkTextField(
          controller: _loginPhoneController,
          hintText: '777 000 00 00',
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          prefixText: '+7 ',
          inputFormatters: const [KazakhstanPhoneInputFormatter()],
        ),
        const SizedBox(height: 18),
        _GreenButton(
          text: _isLoading
              ? context.tr('Отправка...', 'Жіберілуде...')
              : context.tr('Получить код', 'Код алу'),
          onPressed: _isLoading ? null : _submitLogin,
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      key: const ValueKey('register_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Регистрация ресторана', 'Мейрамхананы тіркеу'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(
            'Заполните данные ресторана',
            'Мейрамхана деректерін толтырыңыз',
          ),
          style: const TextStyle(color: Color(0xFF95A0B3), fontSize: 13),
        ),
        const SizedBox(height: 18),
        _FieldLabel(context.tr('Телефон', 'Телефон')),
        const SizedBox(height: 8),
        _DarkTextField(
          controller: _registerPhoneController,
          hintText: '777 000 00 00',
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          prefixText: '+7 ',
          inputFormatters: const [KazakhstanPhoneInputFormatter()],
        ),
        const SizedBox(height: 14),
        _FieldLabel(context.tr('Название на русском', 'Орысша атауы')),
        const SizedBox(height: 8),
        _DarkTextField(
          controller: _nameRuController,
          hintText: context.tr('Название ресторана', 'Мейрамхана атауы'),
          prefixIcon: Icons.storefront_outlined,
        ),
        const SizedBox(height: 14),
        _FieldLabel(context.tr('Название на казахском', 'Қазақша атауы')),
        const SizedBox(height: 8),
        _DarkTextField(
          controller: _nameKkController,
          hintText: context.tr('Название ресторана', 'Мейрамхана атауы'),
          prefixIcon: Icons.storefront_outlined,
        ),
        const SizedBox(height: 14),
        _FieldLabel(context.tr('Адрес', 'Мекенжай')),
        const SizedBox(height: 8),
        _DarkTextField(
          controller: _addressController,
          hintText: context.tr('Город, улица, дом', 'Қала, көше, үй'),
          prefixIcon: Icons.location_on_outlined,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel(context.tr('Открытие', 'Ашылуы')),
                  const SizedBox(height: 8),
                  _TimeField(
                    text: _formatTime(_openTime),
                    onTap: () => _pickTime(true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel(context.tr('Закрытие', 'Жабылуы')),
                  const SizedBox(height: 8),
                  _TimeField(
                    text: _formatTime(_closeTime),
                    onTap: () => _pickTime(false),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _registrationConsentAccepted,
              activeColor: const Color(0xFF489F2A),
              side: const BorderSide(color: Color(0xFF6F7D91)),
              onChanged: _isLoading
                  ? null
                  : (value) => setState(
                        () => _registrationConsentAccepted = value ?? false,
                      ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      context.tr(
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
                    children: [
                      _DocumentButton(
                        label: context.tr(
                          'Политика конфиденциальности',
                          'Құпиялылық саясаты',
                        ),
                        onPressed: () => _openExternalDocument(
                          'https://jetkiz.asia/privacy',
                        ),
                      ),
                      _DocumentButton(
                        label: context.tr(
                          'Согласие на обработку данных',
                          'Деректерді өңдеуге келісім',
                        ),
                        onPressed: () => _openExternalDocument(
                          'https://jetkiz.asia/consent',
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
              ? context.tr('Отправка...', 'Жіберілуде...')
              : context.tr('Продолжить', 'Жалғастыру'),
          onPressed: _isLoading ? null : _submitRegister,
        ),
      ],
    );
  }
}

class _LanguageSwitcher extends StatelessWidget {
  const _LanguageSwitcher({required this.kazakh, required this.onToggle});

  final bool kazakh;
  final Future<void> Function() onToggle;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onToggle,
      child: Text(
        kazakh ? 'RU' : 'ҚАЗ',
        style: const TextStyle(
          color: Color(0xFF65C044),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AuthTabs extends StatelessWidget {
  const _AuthTabs({required this.tab, required this.onChanged});

  final RestaurantAuthTab tab;
  final ValueChanged<RestaurantAuthTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22324A)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AuthTabButton(
              title: context.tr('Вход', 'Кіру'),
              active: tab == RestaurantAuthTab.login,
              onTap: () => onChanged(RestaurantAuthTab.login),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AuthTabButton(
              title: context.tr('Регистрация', 'Тіркелу'),
              active: tab == RestaurantAuthTab.register,
              onTap: () => onChanged(RestaurantAuthTab.register),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthTabButton extends StatelessWidget {
  const _AuthTabButton({
    required this.title,
    required this.active,
    required this.onTap,
  });

  final String title;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 46,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF489F2A) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF95A0B3),
            fontWeight: FontWeight.w800,
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
    this.onChanged,
    this.prefixText,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;

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
        onChanged: onChanged,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF6F7D91)),
          prefixIcon: Icon(prefixIcon, color: const Color(0xFF8E9AAF)),
          prefixText: prefixText,
          prefixStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF101827),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A3950)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.access_time_outlined,
              color: Color(0xFF8E9AAF),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: const TextStyle(color: Colors.white)),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Color(0xFF8E9AAF)),
          ],
        ),
      ),
    );
  }
}

class _DocumentButton extends StatelessWidget {
  const _DocumentButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: const Color(0xFF65C044),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
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
