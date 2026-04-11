import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final bool hasSession = await _storage.hasSession();

    if (!hasSession) {
      _openLogin();
      return;
    }

    try {
      await _authApi.getMe();
      _openShell();
    } catch (_) {
      await _storage.clearTokens();
      _openLogin();
    }
  }

  void _openLogin() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      AppPageRoute<void>(
        page: const RestaurantAuthPage(),
      ),
    );
  }

  void _openShell() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      AppPageRoute<void>(
        page: const RestaurantShellPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0B0B0C),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF489F2A),
        ),
      ),
    );
  }
}
