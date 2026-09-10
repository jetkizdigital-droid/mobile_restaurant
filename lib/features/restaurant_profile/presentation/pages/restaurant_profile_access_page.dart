import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/localization/app_locale_controller.dart';
import 'package:jetkiz_restaurant/features/restaurant_profile/presentation/pages/restaurant_profile_page.dart';
import 'package:jetkiz_restaurant/features/restaurant_profile/presentation/pages/restaurant_staff_management_page.dart';

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
        if (isOwner)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Material(
                color: const Color(0xFF151922),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RestaurantStaffManagementPage(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.groups_2_outlined,
                          color: Color(0xFF65C044),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('Сотрудники', 'Қызметкерлер'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                context.tr(
                                  'Роли, филиалы и доступ сотрудников',
                                  'Рөлдер, филиалдар және қызметкерлердің қолжетімділігі',
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF95A0B3),
                                  fontSize: 12,
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
          ),
        const Expanded(
          child: RestaurantProfilePage(hideBottomBar: true),
        ),
      ],
    );
  }
}
