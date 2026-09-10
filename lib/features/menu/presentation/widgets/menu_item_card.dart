import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/config/app_config.dart';
import 'package:jetkiz_restaurant/core/localization/app_locale_controller.dart';

import '../../domain/restaurant_menu_models.dart';

class MenuItemCard extends StatelessWidget {
  const MenuItemCard({
    super.key,
    required this.item,
    required this.categoryTitle,
    required this.onToggleAvailability,
    required this.onEdit,
    required this.onDelete,
  });

  final RestaurantMenuItem item;
  final String categoryTitle;
  final VoidCallback onToggleAvailability;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _resolveImage() {
    try {
      final main = item.images.firstWhere((image) => image.isMain);
      if (main.url.trim().isNotEmpty) return main.url.trim();
    } catch (_) {}
    return (item.imageUrl ?? '').trim();
  }

  String _toFullImageUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '${AppConfig.baseUrl}$url';
  }

  String _title(BuildContext context) {
    final primary = context.isKazakh ? item.titleKk : item.titleRu;
    final fallback = context.isKazakh ? item.titleRu : item.titleKk;
    if (primary.trim().isNotEmpty) return primary.trim();
    if (fallback.trim().isNotEmpty) return fallback.trim();
    return context.tr('Блюдо', 'Тағам');
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _toFullImageUrl(_resolveImage());
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2438), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF25324A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 80,
                height: 80,
                color: const Color(0xFF111827),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
                      )
                    : const _ImagePlaceholder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 82,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _title(context),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (item.description ?? '').trim().isEmpty
                                    ? context.tr(
                                        'Описание отсутствует',
                                        'Сипаттама жоқ',
                                      )
                                    : item.description!.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF8FA1BC),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Semantics(
                          button: true,
                          label: item.isAvailable
                              ? context.tr(
                                  'Убрать блюдо из доступных',
                                  'Тағамды қолжетімді тізімнен алып тастау',
                                )
                              : context.tr(
                                  'Сделать блюдо доступным',
                                  'Тағамды қолжетімді ету',
                                ),
                          child: GestureDetector(
                            onTap: onToggleAvailability,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: item.isAvailable
                                    ? const Color(0xFF4B9E2F)
                                        .withValues(alpha: 0.18)
                                    : const Color(0xFF374151),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                item.isAvailable
                                    ? Icons.power_settings_new
                                    : Icons.power_off,
                                size: 16,
                                color: item.isAvailable
                                    ? const Color(0xFF67D33D)
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          '${item.price} ₸',
                          style: const TextStyle(
                            color: Color(0xFF58C437),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A3346),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              categoryTitle,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF9AA7BD),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        _CircleActionButton(
                          tooltip: context.tr('Изменить', 'Өзгерту'),
                          icon: Icons.edit,
                          background: const Color(0x332563EB),
                          foreground: const Color(0xFF60A5FA),
                          onTap: onEdit,
                        ),
                        const SizedBox(width: 6),
                        _CircleActionButton(
                          tooltip: context.tr('Удалить', 'Жою'),
                          icon: Icons.delete_outline,
                          background: const Color(0x33DC2626),
                          foreground: const Color(0xFFF87171),
                          onTap: onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.tooltip,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 15, color: foreground),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.image_outlined,
        color: Color(0xFF475569),
        size: 24,
      ),
    );
  }
}
