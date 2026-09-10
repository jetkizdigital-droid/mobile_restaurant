import 'package:flutter/material.dart';
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
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.groups_2_outlined,
                          color: Color(0xFF65C044),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Сотрудники',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Роли, филиалы и доступ сотрудников',
                                style: TextStyle(
                                  color: Color(0xFF95A0B3),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
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
