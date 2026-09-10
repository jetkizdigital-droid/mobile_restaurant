import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/localization/app_locale_controller.dart';
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

  String _t(String ru, String kk) => context.tr(ru, kk);

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
      setState(() => _profile = latest);
    } catch (_) {
      // Keep the last known state. Server-side guards remain authoritative.
    } finally {
      _isRefreshing = false;
    }
  }

  String _safeError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    if (raw.isEmpty ||
        raw.length > 180 ||
        lower.contains('dioexception') ||
        lower.contains('socketexception') ||
        lower.contains('exception') ||
        lower.contains('backend') ||
        lower.contains('endpoint') ||
        lower.contains('status code') ||
        lower.contains('http 4') ||
        lower.contains('http 5')) {
      return _t(
        'Не удалось отправить заявку. Проверьте интернет и повторите.',
        'Өтінімді жіберу мүмкін болмады. Интернетті тексеріп, қайталаңыз.',
      );
    }
    return raw;
  }

  Future<void> _resubmitForReview() async {
    if (_isResubmitting || widget.isUpdating) return;
    setState(() => _isResubmitting = true);

    try {
      if (widget.onResubmit != null) {
        widget.onResubmit!();
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await _refreshRestaurantState();
        return;
      }

      final latest = await RestaurantApi(ApiClient.instance).resubmitForReview();
      if (!mounted) return;
      setState(() => _profile = latest);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Заявка повторно отправлена на модерацию',
                'Өтінім модерацияға қайта жіберілді',
              ),
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_safeError(error))));
    } finally {
      if (mounted) setState(() => _isResubmitting = false);
    }
  }

  String _onboardingTitle(RestaurantProfileData profile) {
    switch (profile.normalizedOnboardingStatus) {
      case 'APPROVED':
        return _t('Ресторан одобрен', 'Мейрамхана мақұлданды');
      case 'NEEDS_CHANGES':
        return _t('Нужны изменения', 'Өзгерістер қажет');
      case 'BLOCKED':
        return _t('Ресторан заблокирован', 'Мейрамхана бұғатталды');
      case 'REJECTED':
        return _t('Заявка отклонена', 'Өтінім қабылданбады');
      case 'DRAFT':
        return _t('Заявка не завершена', 'Өтінім аяқталмаған');
      case 'PENDING_REVIEW':
        return profile.isResubmittedForReview
            ? _t('Повторная проверка', 'Қайта тексеру')
            : _t('Заявка на проверке', 'Өтінім тексерілуде');
      case '':
        return _t('Заявка на проверке', 'Өтінім тексерілуде');
      default:
        return _t('Статус ресторана обновляется', 'Мейрамхана мәртебесі жаңартылуда');
    }
  }

  String _onboardingDescription(RestaurantProfileData profile) {
    final note = (profile.onboardingNote ?? '').trim();
    if (note.isNotEmpty && profile.normalizedOnboardingStatus != 'PENDING_REVIEW') {
      return note;
    }

    switch (profile.normalizedOnboardingStatus) {
      case 'APPROVED':
        if (!profile.isPublished) {
          return _t(
            'Ресторан одобрен, но пока не опубликован в JETKIZ.',
            'Мейрамхана мақұлданды, бірақ JETKIZ ішінде әлі жарияланбаған.',
          );
        }
        if (!profile.isOpenBySchedule) {
          return _t(
            'Сейчас ресторан закрыт по графику. Чтобы принимать заказы, измените график работы.',
            'Қазір мейрамхана кесте бойынша жабық. Тапсырыс қабылдау үшін жұмыс кестесін өзгертіңіз.',
          );
        }
        return profile.isTakingOrders
            ? _t(
                'Ресторан опубликован и принимает заказы.',
                'Мейрамхана жарияланған және тапсырыс қабылдап жатыр.',
              )
            : _t(
                'Ресторан опубликован. Приём заказов приостановлен.',
                'Мейрамхана жарияланған. Тапсырыс қабылдау тоқтатылған.',
              );
      case 'NEEDS_CHANGES':
      case 'REJECTED':
        return _t(
          'Исправьте данные ресторана и отправьте заявку на повторную проверку.',
          'Мейрамхана деректерін түзетіп, өтінімді қайта тексеруге жіберіңіз.',
        );
      case 'BLOCKED':
        final reason = (profile.blockReason ?? '').trim();
        if (reason.isNotEmpty) return reason;
        return _t(
          'Ресторан скрыт из клиентского приложения. Для уточнения обратитесь в поддержку.',
          'Мейрамхана клиенттік қосымшадан жасырылды. Толық ақпарат үшін қолдауға жазыңыз.',
        );
      case 'PENDING_REVIEW':
        return profile.isResubmittedForReview
            ? _t(
                'Исправления отправлены. Ожидайте решения JETKIZ.',
                'Түзетулер жіберілді. JETKIZ шешімін күтіңіз.',
              )
            : _t(
                'Заявка отправлена. Ожидайте решения JETKIZ.',
                'Өтінім жіберілді. JETKIZ шешімін күтіңіз.',
              );
      default:
        return _t(
          'После одобрения ресторан сможет появиться в JETKIZ и принимать заказы.',
          'Мақұлданғаннан кейін мейрамхана JETKIZ ішінде көрініп, тапсырыс қабылдай алады.',
        );
    }
  }

  String _commissionText(RestaurantProfileData profile) {
    final value = profile.effectiveRestaurantCommissionPct;
    final rate = value != null && value.isFinite ? '${value.round()}%' : '—';
    final type = profile.hasIndividualCommission
        ? _t('Индивидуальная', 'Жеке')
        : _t('Общая', 'Жалпы');
    return '${_t('Комиссия JETKIZ', 'JETKIZ комиссиясы')}: $rate · $type';
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
    if (!approved || !published) {
      title = _onboardingTitle(profile);
      description = _onboardingDescription(profile);
    } else if (!openBySchedule) {
      title = _t('Закрыто по графику', 'Кесте бойынша жабық');
      description = _t(
        'Приём заказов нельзя включить вне рабочего времени. Сначала измените график ресторана.',
        'Жұмыс уақытынан тыс тапсырыс қабылдауды қосу мүмкін емес. Алдымен мейрамхана кестесін өзгертіңіз.',
      );
    } else if (accepting) {
      title = _t('Принимаем заказы', 'Тапсырыс қабылдаймыз');
      description = _t(
        'Новые заказы доступны ресторану.',
        'Жаңа тапсырыстар мейрамханаға қолжетімді.',
      );
    } else {
      title = _t('Приём заказов приостановлен', 'Тапсырыс қабылдау тоқтатылды');
      description = _t(
        'Текущие заказы продолжают выполняться. Новые не принимаются.',
        'Ағымдағы тапсырыстар орындала береді. Жаңа тапсырыстар қабылданбайды.',
      );
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
                    _commissionText(profile),
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
                    label: Text(
                      _t(
                        'Отправить на повторную проверку',
                        'Қайта тексеруге жіберу',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
                activeThumbColor: const Color(0xFF65C044),
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
