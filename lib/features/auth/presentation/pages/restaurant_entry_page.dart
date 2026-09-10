import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/localization/app_locale_controller.dart';
import 'package:jetkiz_restaurant/core/navigation/app_page_route.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_api.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_storage.dart';
import 'package:jetkiz_restaurant/features/auth/presentation/pages/restaurant_access_choice_page.dart';
import 'package:jetkiz_restaurant/features/navigation/presentation/pages/restaurant_shell_page.dart';

class RestaurantEntryPage extends StatefulWidget {
  const RestaurantEntryPage({super.key});

  @override
  State<RestaurantEntryPage> createState() => _RestaurantEntryPageState();
}

class _RestaurantEntryPageState extends State<RestaurantEntryPage> {
  final AuthStorage _storage = AuthStorage();
  final AuthApi _authApi = AuthApi();
  String? _bootstrapError;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_isRetrying) return;
    if (mounted) {
      setState(() {
        _isRetrying = true;
        _bootstrapError = null;
      });
    }

    final hasSession = await _storage.hasSession();
    if (!hasSession) {
      _openLogin();
      return;
    }

    try {
      await _authApi.getMe();
      _openShell();
    } on ApiException catch (error) {
      if (error.isInvalidSession) {
        await _storage.clearTokens();
        ApiClient.instance.clearSelectedRestaurantId();
        _openLogin();
        return;
      }
      _showRetry(_safeError(error.message));
    } catch (_) {
      _showRetry(_fallbackError());
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  String _fallbackError() {
    return context.tr(
      'Не удалось проверить вход. Проверьте интернет и повторите.',
      'Кіруді тексеру мүмкін болмады. Интернетті тексеріп, қайталаңыз.',
    );
  }

  String _safeError(String message) {
    final raw = message.trim();
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
      return _fallbackError();
    }
    return raw;
  }

  void _showRetry(String message) {
    if (!mounted) return;
    setState(() => _bootstrapError = message);
  }

  void _openLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      AppPageRoute<void>(page: const RestaurantAccessChoicePage()),
    );
  }

  void _openShell() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      AppPageRoute<void>(page: const RestaurantShellPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0C),
      body: Center(
        child: _bootstrapError == null
            ? const CircularProgressIndicator(color: Color(0xFF489F2A))
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _bootstrapError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isRetrying ? null : _bootstrap,
                      child: Text(context.tr('Повторить', 'Қайталау')),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
