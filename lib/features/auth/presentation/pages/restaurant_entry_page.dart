import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_api.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_storage.dart';
import 'package:jetkiz_restaurant/features/auth/presentation/pages/restaurant_auth_page.dart';
import 'package:jetkiz_restaurant/features/navigation/presentation/pages/restaurant_shell_page.dart';
import 'package:jetkiz_restaurant/core/navigation/app_page_route.dart';

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

    final bool hasSession = await _storage.hasSession();

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
      _showRetry(error.message);
    } catch (_) {
      _showRetry('Не удалось проверить сессию');
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  void _showRetry(String message) {
    if (!mounted) return;
    setState(() => _bootstrapError = message);
  }

  void _openLogin() {
    if (!mounted) return;

    Navigator.of(
      context,
    ).pushReplacement(AppPageRoute<void>(page: const RestaurantAuthPage()));
  }

  void _openShell() {
    if (!mounted) return;

    Navigator.of(
      context,
    ).pushReplacement(AppPageRoute<void>(page: const RestaurantShellPage()));
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
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
