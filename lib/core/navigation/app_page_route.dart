import 'package:flutter/material.dart';

class AppPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  AppPageRoute({required this.page})
    : super(
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final offsetAnimation =
              Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );

          final fadeAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
      );
}
