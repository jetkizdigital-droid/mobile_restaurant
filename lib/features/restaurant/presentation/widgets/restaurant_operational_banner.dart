import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/restaurant/data/restaurant_api.dart';
import 'package:jetkiz_restaurant/features/restaurant/domain/restaurant_profile_data.dart';

class RestaurantOperationalBanner extends StatefulWidget {
  const RestaurantOperationalBanner({
    super.key,
    required this.profile,
    required this.isUpdating,
    required this.onAcceptingOrdersChanged,
    this.onResubmit,
  });

  final RestaurantProfileData profile;
  final bool isUpdating;
  final ValueChanged<bool> onAcceptingOrdersChanged;
  final VoidCallback? onResubmit;

  @override
  State<RestaurantOperationalBanner> createState() =>
      _RestaurantOperationalBannerState();
}

class _RestaurantOperationalBannerState
    extends State<RestaurantOperationalBanner> {
  Timer? _refreshTimer;
  late RestaurantProfileData _profile;
  bool _isRefreshing = false;
  bool _isResubmitting = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_refreshRestaurantState()),
    );
  }

  @override
  void didUpdateWidget(covariant RestaurantOperationalBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      _profile = widget.profile;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshRestaurantState() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final latest = await RestaurantApi(ApiClient.instance).getMyRestaurant();
      if (!mounted) return;
      setState(() {
        _profile = latest;
      });
    } catch (_) {
      // Keep the last known state. Backend guards remain authoritative.
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _resubmitForReview() async {
    if (_isResubmitting || widget.isUpdating) return;

    setState(() {
      _isResubmitting = true;
    });

    try {
      if (widget.onResubmit != null) {
        widget.onResubmit!();
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await _refreshRestaurantState();
        return;
      }

      final latest = await RestaurantApi(
        ApiClient.instance,
      ).resubmitForReview();
      if (!mounted) return;
      setState(() {
        _profile = latest;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Заявка повторно отправлена на модерацию'),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst('Exception: ', '').trim(),
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isResubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final approved = profile.isApproved;
    final blocked = profile.isBlocked;
    final needsAttention = profile.needsOnboardingAttention;
    final published = profile.isPublished;
    final accepting = profile.isTakingOrders;
    final openBySchedule = profile.isOpenBySchedule;

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
        ? (profile.isEffectivelyTakingOrders
              ? Icons.storefront_rounded
              : Icons.pause_circle_outline_rounded)
        : Icons.hourglass_top_rounded;

    String title;
    String description;

    if (!approved) {
      title = profile.onboardingTitle;
      description = profile.onboardingDescription;
    } else if (!published) {
      title = profile.onboardingTitle;
      description = profile.onboardingDescription;
    } else if (!openBySchedule) {
      title = 'Закрыто по графику';
      description =
          'Приём заказов нельзя включить вне рабочего времени. Сначала измените график ресторана.';
    } else if (accepting) {
      title = 'Принимаем заказы';
      description = 'Новые заказы доступны ресторану.';
    } else {
      title = 'Приём заказов приостановлен';
      description =
          'Текущие заказы продолжают выполняться. Новые не принимаются.';
    }

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
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
                if (profile.effectiveRestaurantCommissionPct != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Комиссия JETKIZ: ${profile.displayCommission} · ${profile.commissionTypeLabel}',
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (profile.canResubmitForReview) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: widget.isUpdating || _isResubmitting
                        ? null
                        : _resubmitForReview,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF7F1D1D),
                    ),
                    icon: _isResubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text(
                      'Отправить на повторную проверку',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (approved && published && !blocked) ...[
            const SizedBox(width: 8),
            if (widget.isUpdating)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Switch.adaptive(
                value: accepting,
                activeColor: const Color(0xFF65C044),
                onChanged: accepting || profile.canEnableAcceptingOrders
                    ? widget.onAcceptingOrdersChanged
                    : null,
              ),
          ],
        ],
      ),
    );
  }
}
