import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_api.dart';
import 'restaurant_sms_page.dart';

enum RestaurantAuthTab { login, register }

class RestaurantAuthPage extends StatefulWidget {
  const RestaurantAuthPage({super.key});

  @override
  State<RestaurantAuthPage> createState() => _RestaurantAuthPageState();
}

class _RestaurantAuthPageState extends State<RestaurantAuthPage> {
  final AuthApi _authApi = AuthApi();

  RestaurantAuthTab _tab = RestaurantAuthTab.login;
  bool _isLoading = false;

  final TextEditingController _loginPhoneController = TextEditingController();
  final TextEditingController _registerPhoneController =
      TextEditingController();
  final TextEditingController _nameRuController = TextEditingController();
  final TextEditingController _nameKkController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

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

  String _formatPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    String normalized = digits;
    if (normalized.startsWith('8')) {
      normalized = '7${normalized.substring(1)}';
    }
    if (!normalized.startsWith('7') && normalized.isNotEmpty) {
      normalized = '7$normalized';
    }
    if (normalized.length > 11) {
      normalized = normalized.substring(0, 11);
    }

    final buffer = StringBuffer('+7');
    if (normalized.length > 1) {
      buffer.write(
        ' (${normalized.substring(1, normalized.length >= 4 ? 4 : normalized.length)}',
      );
    }
    if (normalized.length >= 4) {
      buffer.write(')');
    }
    if (normalized.length >= 5) {
      buffer.write(
        ' ${normalized.substring(4, normalized.length >= 7 ? 7 : normalized.length)}',
      );
    }
    if (normalized.length >= 8) {
      buffer.write(
        '-${normalized.substring(7, normalized.length >= 9 ? 9 : normalized.length)}',
      );
    }
    if (normalized.length >= 10) {
      buffer.write(
        '-${normalized.substring(9, normalized.length >= 11 ? 11 : normalized.length)}',
      );
    }

    return buffer.toString();
  }

  String _normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return '';
    }

    String normalized = digits;

    if (normalized.startsWith('8')) {
      normalized = '7${normalized.substring(1)}';
    }

    if (!normalized.startsWith('7')) {
      normalized = '7$normalized';
    }

    if (normalized.length > 11) {
      normalized = normalized.substring(0, 11);
    }

    return '+$normalized';
  }

  bool _isValidPhone(String value) {
    return _normalizePhone(value).replaceAll('+', '').length == 11;
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _onPhoneChanged(TextEditingController controller, String raw) {
    final formatted = _formatPhone(raw);
    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _pickTime(bool isOpen) async {
    final initial = isOpen ? _openTime : _closeTime;

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF489F2A),
              surface: Color(0xFF121826),
              onPrimary: Colors.white,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isOpen) {
          _openTime = picked;
        } else {
          _closeTime = picked;
        }
      });
    }
  }

  Future<void> _submitLogin() async {
    final phone = _loginPhoneController.text.trim();

    if (!_isValidPhone(phone)) {
      _showError('Enter a valid phone number');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final normalizedPhone = _normalizePhone(phone);

      try {
        await _authApi.requestCode(phone: normalizedPhone);
      } catch (e) {
        if (!mounted) return;
        final message = e.toString().replaceFirst('Exception: ', '').trim();
        _showError(message.isEmpty ? 'Не удалось отправить SMS-код' : message);
        return;
      }

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RestaurantSmsPage(
            phone: normalizedPhone,
            isNewUser: false,
            registerData: null,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitRegister() async {
    final phone = _registerPhoneController.text.trim();
    final nameRu = _nameRuController.text.trim();
    final nameKk = _nameKkController.text.trim();
    final address = _addressController.text.trim();
    final workingHoursFrom = _formatTime(_openTime);
    final workingHoursTo = _formatTime(_closeTime);

    if (!_isValidPhone(phone)) {
      _showError('Enter a valid phone number');
      return;
    }

    if (nameRu.isEmpty || nameKk.isEmpty || address.isEmpty) {
      _showError('Fill in all required fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final normalizedPhone = _normalizePhone(phone);

      try {
        await _authApi.requestCode(phone: normalizedPhone);
      } catch (e) {
        if (!mounted) return;
        final message = e.toString().replaceFirst('Exception: ', '').trim();
        _showError(message.isEmpty ? 'Не удалось отправить SMS-код' : message);
        return;
      }

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RestaurantSmsPage(
            phone: normalizedPhone,
            isNewUser: true,
            registerData: {
              'nameRu': nameRu,
              'nameKk': nameKk,
              'address': address,
              'workingHoursFrom': workingHoursFrom,
              'workingHoursTo': workingHoursTo,
            },
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
            colors: [backgroundTop, Color(0xFF0B1524), backgroundBottom],
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
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Jetkiz',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Restaurant account access',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: panelColor.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _AuthTabButton(
                              title: 'Login',
                              isActive: _tab == RestaurantAuthTab.login,
                              onTap: () {
                                setState(() {
                                  _tab = RestaurantAuthTab.login;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _AuthTabButton(
                              title: 'Register',
                              isActive: _tab == RestaurantAuthTab.register,
                              onTap: () {
                                setState(() {
                                  _tab = RestaurantAuthTab.register;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
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
        const Text(
          'Welcome back',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your phone number',
          style: TextStyle(color: Color(0xFF95A0B3), fontSize: 13),
        ),
        const SizedBox(height: 22),
        const _FieldLabel('Phone number'),
        const SizedBox(height: 8),
        _DarkTextField(
          controller: _loginPhoneController,
          hintText: '+7 (___) ___-__-__',
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          onChanged: (value) => _onPhoneChanged(_loginPhoneController, value),
        ),
        const SizedBox(height: 18),
        _GreenButton(
          text: _isLoading ? 'Sending...' : 'Send code',
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
        const Text(
          'Register restaurant',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Fill in restaurant data',
          style: TextStyle(color: Color(0xFF95A0B3), fontSize: 13),
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Phone number'),
        const SizedBox(height: 8),
        _DarkTextField(
          controller: _registerPhoneController,
          hintText: '+7 (___) ___-__-__',
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          onChanged: (value) =>
              _onPhoneChanged(_registerPhoneController, value),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Restaurant name (RU)'),
                  const SizedBox(height: 8),
                  _DarkTextField(
                    controller: _nameRuController,
                    hintText: 'Restaurant name',
                    prefixIcon: Icons.storefront_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Restaurant name (KK)'),
                  const SizedBox(height: 8),
                  _DarkTextField(
                    controller: _nameKkController,
                    hintText: 'Restaurant name',
                    prefixIcon: Icons.storefront_outlined,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Address'),
        const SizedBox(height: 8),
        _DarkTextField(
          controller: _addressController,
          hintText: 'City, street, building',
          prefixIcon: Icons.location_on_outlined,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Open time'),
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
                  const _FieldLabel('Close time'),
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
        const SizedBox(height: 20),
        _GreenButton(
          text: _isLoading ? 'Sending...' : 'Continue',
          onPressed: _isLoading ? null : _submitRegister,
        ),
      ],
    );
  }
}

class _AuthTabButton extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _AuthTabButton({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 46,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF489F2A) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF95A0B3),
            fontSize: 14,
            fontWeight: FontWeight.w700,
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
  final ValueChanged<String>? onChanged;

  const _DarkTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType,
    this.onChanged,
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
        onChanged: onChanged,
        keyboardType: keyboardType,
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

class _TimeField extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _TimeField({required this.text, required this.onTap});

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
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Color(0xFF8E9AAF)),
          ],
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
