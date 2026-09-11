import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/localization/app_locale_controller.dart';
import 'package:jetkiz_restaurant/features/restaurant_profile/presentation/pages/restaurant_profile_page.dart';
import 'package:jetkiz_restaurant/features/restaurant_profile/presentation/pages/restaurant_staff_management_v2_page.dart';

class RestaurantProfileAccessPage extends StatelessWidget {
  const RestaurantProfileAccessPage({
    super.key,
    required this.isOwner,
  });

  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                if (isOwner)
                  Expanded(
                    child: Material(
                      color: const Color(0xFF151922),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const RestaurantStaffManagementPage(),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.groups_2_outlined,
                                color: Color(0xFF65C044),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr('Сотрудники', 'Қызметкерлер'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      context.tr(
                                        'Роли и филиалы',
                                        'Рөлдер мен филиалдар',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF95A0B3),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF95A0B3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (isOwner) const SizedBox(width: 10),
                Material(
                  color: const Color(0xFF151922),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: AppLocaleController.instance.toggle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 15,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.language_rounded,
                            color: Color(0xFF65C044),
                            size: 20,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            context.isKazakh ? 'RU' : 'ҚАЗ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Expanded(
          child: RestaurantProfilePage(hideBottomBar: true),
        ),
      ],
    );
  }
}
