import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/config/app_config.dart';
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
      final main = item.images.firstWhere((e) => e.isMain);
      if (main.url.trim().isNotEmpty) return main.url.trim();
    } catch (_) {}

    return (item.imageUrl ?? '').trim();
  }

  String _toFullImageUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return '${AppConfig.baseUrl}$url';
  }

  @override
  Widget build(BuildContext context) {
    final rawImageUrl = _resolveImage();
    final imageUrl = _toFullImageUrl(rawImageUrl);
    final hasImage = imageUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2438), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF25324A),
          width: 1,
        ),
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
                child: hasImage
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
                height: 80,
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
                                item.titleRu,
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
                                    ? 'Описание отсутствует'
                                    : item.description!.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF8FA1BC),
                                  fontSize: 11,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onToggleAvailability,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: item.isAvailable
                                  ? const Color(0xFF4B9E2F).withOpacity(0.18)
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
                          icon: Icons.edit,
                          bg: const Color(0xFF2563EB).withOpacity(0.18),
                          color: const Color(0xFF60A5FA),
                          onTap: onEdit,
                        ),
                        const SizedBox(width: 6),
                        _CircleActionButton(
                          icon: Icons.delete_outline,
                          bg: const Color(0xFFDC2626).withOpacity(0.18),
                          color: const Color(0xFFF87171),
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
    required this.icon,
    required this.bg,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color bg;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 15, color: color),
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