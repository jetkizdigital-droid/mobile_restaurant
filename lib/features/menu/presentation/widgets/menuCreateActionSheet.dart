import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/localization/app_locale_controller.dart';

class MenuCreateActionSheet extends StatelessWidget {
  const MenuCreateActionSheet({
    super.key,
    required this.onAddProduct,
    required this.onAddCategory,
  });

  final VoidCallback onAddProduct;
  final VoidCallback onAddCategory;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(color: Colors.black.withValues(alpha: 0.35)),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1C2C44), Color(0xFF0F1B2D)],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    context.tr('Выберите действие', 'Әрекетті таңдаңыз'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ActionCard(
                    accent: const Color(0xFF6BCB3D),
                    background: const LinearGradient(
                      colors: [Color(0xFF4CAF2A), Color(0xFF419A25)],
                    ),
                    icon: Icons.restaurant_menu,
                    title: context.tr('Создать блюдо', 'Тағам қосу'),
                    subtitle: context.tr(
                      'Добавить новое блюдо в меню',
                      'Мәзірге жаңа тағам қосу',
                    ),
                    onTap: onAddProduct,
                  ),
                  const SizedBox(height: 12),
                  _ActionCard(
                    accent: const Color(0xFFB388FF),
                    background: const LinearGradient(
                      colors: [Color(0xFF2B3E57), Color(0xFF223248)],
                    ),
                    icon: Icons.add_box_outlined,
                    title: context.tr('Создать категорию', 'Санат қосу'),
                    subtitle: context.tr(
                      'Добавить новую категорию',
                      'Жаңа санат қосу',
                    ),
                    onTap: onAddCategory,
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      context.tr('Отмена', 'Бас тарту'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.accent,
    required this.background,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color accent;
  final Gradient background;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
