import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/features/restaurant/domain/restaurant_profile_data.dart';

class RestaurantOperationalBanner extends StatelessWidget {
  const RestaurantOperationalBanner({
    super.key,
    required this.profile,
    required this.isUpdating,
    required this.onAcceptingOrdersChanged,
  });

  final RestaurantProfileData profile;
  final bool isUpdating;
  final ValueChanged<bool> onAcceptingOrdersChanged;

  @override
  Widget build(BuildContext context) {
    final approved = profile.isApproved;
    final blocked = profile.isBlocked;
    final needsAttention = profile.needsOnboardingAttention;
    final published = profile.isPublished;
    final accepting = profile.isTakingOrders;

    final background = blocked || needsAttention
        ? const Color(0xFF3A1A1A)
        : approved
            ? const Color(0xFF102717)
            : const Color(0xFF30270F);
    final border = blocked || needsAttention
        ? const Color(0xFF7F1D1D)
        : approved
            ? const Color(0xFF2F6E2B)
            : const Color(0xFF6B5315);
    final icon = blocked || needsAttention
        ? Icons.warning_amber_rounded
        : approved
            ? (accepting
                ? Icons.storefront_rounded
                : Icons.pause_circle_outline_rounded)
            : Icons.hourglass_top_rounded;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  approved
                      ? (accepting
                          ? 'Принимаем заказы'
                          : 'Приём заказов приостановлен')
                      : profile.onboardingTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  approved
                      ? (published
                          ? 'Можно временно остановить или возобновить приём заказов.'
                          : profile.onboardingDescription)
                      : profile.onboardingDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (approved && published && !blocked) ...[
            const SizedBox(width: 8),
            if (isUpdating)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Switch.adaptive(
                value: accepting,
                activeColor: const Color(0xFF65C044),
                onChanged: onAcceptingOrdersChanged,
              ),
          ],
        ],
      ),
    );
  }
}
