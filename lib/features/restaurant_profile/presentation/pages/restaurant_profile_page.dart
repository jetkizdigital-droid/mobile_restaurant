import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jetkiz_restaurant/core/config/app_config.dart';
import 'package:jetkiz_restaurant/core/localization/app_locale_controller.dart';
import 'package:jetkiz_restaurant/core/navigation/app_page_route.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/core/push/restaurant_push_notification_service.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_api.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_storage.dart';
import 'package:jetkiz_restaurant/features/auth/presentation/pages/restaurant_access_choice_page.dart';
import 'package:jetkiz_restaurant/features/restaurant/data/restaurant_api.dart';
import 'package:jetkiz_restaurant/features/restaurant/domain/restaurant_profile_data.dart';
import 'package:jetkiz_restaurant/features/restaurant_profile/widgets/restaurant_statistics_tab.dart';

class RestaurantProfilePage extends StatefulWidget {
  const RestaurantProfilePage({
    super.key,
    this.hideBottomBar = false,
    this.onBranchChanged,
  });

  final bool hideBottomBar;
  final Future<void> Function(String restaurantId)? onBranchChanged;

  @override
  State<RestaurantProfilePage> createState() => _RestaurantProfilePageState();
}

enum _RestaurantProfileTab { profile, statistics }

class _RestaurantProfilePageState extends State<RestaurantProfilePage> {
  late final RestaurantApi _restaurantApi;
  late final AuthApi _authApi;
  final ImagePicker _imagePicker = ImagePicker();

  Future<RestaurantProfileData>? _profileFuture;
  _RestaurantProfileTab _activeTab = _RestaurantProfileTab.profile;

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _isLoadingBranches = false;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _workingHoursController = TextEditingController();

  List<_RestaurantBranch> _branches = const <_RestaurantBranch>[];
  String? _selectedRestaurantId;
  String? _lastProfileSyncKey;
  File? _localPhotoPreview;
  int _photoCacheBuster = DateTime.now().millisecondsSinceEpoch;

  String _t(String ru, String kk) => context.tr(ru, kk);

  @override
  void initState() {
    super.initState();
    _restaurantApi = RestaurantApi(ApiClient.instance);
    _authApi = AuthApi();
    _profileFuture = _restaurantApi.getMyRestaurant();
    _loadBranches();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _workingHoursController.dispose();
    super.dispose();
  }

  String _safeError(
    Object error,
    String fallbackRu,
    String fallbackKk,
  ) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    if (raw.isEmpty ||
        raw.length > 200 ||
        lower.contains('dioexception') ||
        lower.contains('socketexception') ||
        lower.contains('exception') ||
        lower.contains('backend') ||
        lower.contains('endpoint') ||
        lower.contains('status code') ||
        lower.contains('http 4') ||
        lower.contains('http 5')) {
      return _t(fallbackRu, fallbackKk);
    }
    return raw;
  }

  Future<void> _reloadProfile() async {
    if (!mounted) return;
    setState(() => _profileFuture = _restaurantApi.getMyRestaurant());
    await _profileFuture;
  }

  Future<void> _loadBranches() async {
    if (_isLoadingBranches) return;
    if (mounted) setState(() => _isLoadingBranches = true);

    try {
      final me = await _authApi.getMe();
      final branches = _parseBranches(me);
      final savedRestaurantId = await AuthStorage().getSelectedRestaurantId();
      final apiRestaurantId = ApiClient.instance.selectedRestaurantId;
      final accountRestaurantId = me['restaurantId']?.toString().trim();

      var selected = _normalizeId(savedRestaurantId) ??
          _normalizeId(apiRestaurantId) ??
          _normalizeId(accountRestaurantId);

      if (branches.isNotEmpty &&
          (selected == null || !branches.any((branch) => branch.id == selected))) {
        selected = branches.first.id;
        await ApiClient.instance.setSelectedRestaurantId(selected);
      }

      if (!mounted) return;
      setState(() {
        _branches = branches;
        _selectedRestaurantId = selected;
      });
    } catch (error) {
      debugPrint('Restaurant branches load failed: $error');
    } finally {
      if (mounted) setState(() => _isLoadingBranches = false);
    }
  }

  List<_RestaurantBranch> _parseBranches(Map<String, dynamic> payload) {
    final result = <_RestaurantBranch>[];
    final seen = <String>{};

    void add({required String? id, String? nameRu, String? nameKk}) {
      final normalizedId = _normalizeId(id);
      if (normalizedId == null || seen.contains(normalizedId)) return;
      seen.add(normalizedId);
      result.add(
        _RestaurantBranch(
          id: normalizedId,
          nameRu: _normalizeText(nameRu),
          nameKk: _normalizeText(nameKk),
          ordinal: result.length + 1,
        ),
      );
    }

    final restaurants = payload['restaurants'];
    if (restaurants is List) {
      for (final item in restaurants.whereType<Map>()) {
        add(
          id: item['id']?.toString(),
          nameRu: item['nameRu']?.toString(),
          nameKk: item['nameKk']?.toString(),
        );
      }
    }

    final restaurant = payload['restaurant'];
    if (restaurant is Map) {
      add(
        id: restaurant['id']?.toString(),
        nameRu: restaurant['nameRu']?.toString(),
        nameKk: restaurant['nameKk']?.toString(),
      );
    }

    final ids = payload['restaurantIds'];
    if (ids is List) {
      for (final id in ids) {
        add(id: id?.toString());
      }
    }

    final accesses = payload['restaurantAccesses'];
    if (accesses is List) {
      for (final access in accesses.whereType<Map>()) {
        final nested = access['restaurant'];
        if (nested is Map) {
          add(
            id: nested['id']?.toString() ?? access['restaurantId']?.toString(),
            nameRu: nested['nameRu']?.toString(),
            nameKk: nested['nameKk']?.toString(),
          );
        } else {
          add(id: access['restaurantId']?.toString());
        }
      }
    }

    return result;
  }

  String? _normalizeId(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? _normalizeText(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  Future<void> _selectBranch(_RestaurantBranch branch) async {
    if (_selectedRestaurantId == branch.id) return;
    try {
      final onBranchChanged = widget.onBranchChanged;
      if (onBranchChanged != null) {
        await onBranchChanged(branch.id);
        return;
      }

      await ApiClient.instance.setSelectedRestaurantId(branch.id);
      if (!mounted) return;
      setState(() {
        _selectedRestaurantId = branch.id;
        _isEditing = false;
        _lastProfileSyncKey = null;
        _localPhotoPreview = null;
        _profileFuture = _restaurantApi.getMyRestaurant();
      });
      await _profileFuture;
      if (!mounted) return;
      _showSnackBar(
        '${_t('Филиал выбран', 'Филиал таңдалды')}: ${branch.displayName(context)}',
      );
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(
        _safeError(
          error,
          'Не удалось сменить филиал. Попробуйте ещё раз.',
          'Филиалды ауыстыру мүмкін болмады. Қайта көріңіз.',
        ),
      );
    }
  }

  Future<void> _showBranchSelector() async {
    if (_branches.length <= 1) {
      _showSnackBar(_t('У вас один филиал', 'Сізде бір филиал бар'));
      return;
    }

    final selected = await showModalBottomSheet<_RestaurantBranch>(
      context: context,
      backgroundColor: const Color(0xFF0F1829),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF33445F),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _t('Выберите филиал', 'Филиалды таңдаңыз'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.55,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _branches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final branch = _branches[index];
                      final active = branch.id == _selectedRestaurantId;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(sheetContext).pop(branch),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0x223A9F2A)
                                  : const Color(0xFF151F32),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: active
                                    ? const Color(0xFF489F2A)
                                    : const Color(0xFF22324A),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  active
                                      ? Icons.check_circle_rounded
                                      : Icons.storefront_rounded,
                                  color: active
                                      ? const Color(0xFF65C044)
                                      : const Color(0xFF7E8CA3),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    branch.displayName(context),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) await _selectBranch(selected);
  }

  void _syncControllers(RestaurantProfileData profile) {
    final key = <String>[
      profile.id,
      profile.phone ?? '',
      profile.address ?? '',
      profile.workingHours ?? '',
      profile.workingHoursFrom ?? '',
      profile.workingHoursTo ?? '',
    ].join('|');
    if (_lastProfileSyncKey == key) return;

    _phoneController.text = profile.phone?.trim() ?? '';
    _addressController.text = profile.address?.trim() ?? '';
    if (profile.workingHours?.trim().isNotEmpty == true) {
      _workingHoursController.text = profile.workingHours!.trim();
    } else if (profile.workingHoursFrom?.trim().isNotEmpty == true &&
        profile.workingHoursTo?.trim().isNotEmpty == true) {
      _workingHoursController.text =
          '${profile.workingHoursFrom!.trim()} - ${profile.workingHoursTo!.trim()}';
    } else {
      _workingHoursController.clear();
    }
    _lastProfileSyncKey = key;
  }

  Future<void> _saveProfile(RestaurantProfileData profile) async {
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();
    final workingHours = _workingHoursController.text.trim();

    if (address.isEmpty) {
      _showSnackBar(_t('Введите адрес', 'Мекенжайды енгізіңіз'));
      return;
    }
    if (phone.isEmpty) {
      _showSnackBar(_t('Введите телефон', 'Телефонды енгізіңіз'));
      return;
    }
    if (workingHours.isEmpty) {
      _showSnackBar(_t('Введите время работы', 'Жұмыс уақытын енгізіңіз'));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updated = await _restaurantApi.updateMe(
        address: address,
        phone: phone,
        workingHours: workingHours,
      );
      _syncControllers(updated);
      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _profileFuture = Future<RestaurantProfileData>.value(updated);
      });
      await _reloadProfile();
      if (mounted) _showSnackBar(_t('Профиль сохранён', 'Профиль сақталды'));
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(
        _safeError(
          error,
          'Не удалось сохранить профиль. Проверьте данные и повторите.',
          'Профильді сақтау мүмкін болмады. Деректерді тексеріп, қайталаңыз.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<File> _prepareUploadFile(File originalFile) async {
    final path = originalFile.path.toLowerCase();
    if (path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp')) {
      return originalFile;
    }

    final compressed = await FlutterImageCompress.compressAndGetFile(
      originalFile.absolute.path,
      '${originalFile.path}_upload.jpg',
      format: CompressFormat.jpeg,
      quality: 90,
    );
    if (compressed == null) throw const _PhotoPreparationException();
    return File(compressed.path);
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_isUploadingPhoto) return;
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (picked == null) return;

      final uploadFile = await _prepareUploadFile(File(picked.path));
      if (!mounted) return;
      setState(() {
        _localPhotoPreview = uploadFile;
        _isUploadingPhoto = true;
      });

      final updated = await _restaurantApi.uploadRestaurantCover(uploadFile);
      if (!mounted) return;
      setState(() {
        _profileFuture = Future<RestaurantProfileData>.value(updated);
        _localPhotoPreview = null;
        _photoCacheBuster = DateTime.now().millisecondsSinceEpoch;
      });
      await _reloadProfile();
      if (mounted) _showSnackBar(_t('Фото обновлено', 'Фото жаңартылды'));
    } catch (error) {
      if (!mounted) return;
      setState(() => _localPhotoPreview = null);
      _showSnackBar(
        error is _PhotoPreparationException
            ? _t(
                'Не удалось подготовить фото. Выберите другое изображение.',
                'Фотосуретті дайындау мүмкін болмады. Басқа суретті таңдаңыз.',
              )
            : _safeError(
                error,
                'Не удалось загрузить фото. Попробуйте ещё раз.',
                'Фотосуретті жүктеу мүмкін болмады. Қайта көріңіз.',
              ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _logout() async {
    try {
      await RestaurantPushNotificationService.instance.unregisterCurrentToken();
    } catch (_) {}
    try {
      await _authApi.logout();
    } catch (_) {}

    RestaurantPushNotificationService.instance.markNavigationUnavailable();
    await AuthStorage().clearTokens();
    ApiClient.instance.clearSelectedRestaurantId();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      AppPageRoute<void>(page: const RestaurantAccessChoicePage()),
      (route) => false,
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _displayName(RestaurantProfileData profile) {
    final primary = context.isKazakh ? profile.nameKk : profile.nameRu;
    final fallback = context.isKazakh ? profile.nameRu : profile.nameKk;
    final first = primary?.trim() ?? '';
    if (first.isNotEmpty) return first;
    final second = fallback?.trim() ?? '';
    return second.isNotEmpty ? second : _t('Без названия', 'Атаусыз');
  }

  String _displayAddress(RestaurantProfileData profile) {
    final value = profile.address?.trim() ?? '';
    return value.isEmpty ? _t('Адрес не указан', 'Мекенжай көрсетілмеген') : value;
  }

  String _displayPhone(RestaurantProfileData profile) {
    final value = profile.phone?.trim() ?? '';
    return value.isEmpty ? _t('Телефон не указан', 'Телефон көрсетілмеген') : value;
  }

  String _displayWorkingHours(RestaurantProfileData profile) {
    final value = profile.workingHours?.trim() ?? '';
    if (value.isNotEmpty) return value;
    final from = profile.workingHoursFrom?.trim() ?? '';
    final to = profile.workingHoursTo?.trim() ?? '';
    if (from.isNotEmpty && to.isNotEmpty) return '$from - $to';
    return _t('Время не указано', 'Уақыт көрсетілмеген');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      appBar: widget.hideBottomBar
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF09111C),
              title: Text(_t('Мой ресторан', 'Менің мейрамханам')),
            ),
      body: SafeArea(
        child: FutureBuilder<RestaurantProfileData>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ProfileMessageState(
                message: _safeError(
                  snapshot.error!,
                  'Не удалось загрузить профиль. Проверьте интернет и повторите.',
                  'Профильді жүктеу мүмкін болмады. Интернетті тексеріп, қайталаңыз.',
                ),
                actionLabel: _t('Повторить', 'Қайталау'),
                onAction: _reloadProfile,
              );
            }

            final profile = snapshot.data;
            if (profile == null) {
              return _ProfileMessageState(
                message: _t('Профиль не найден', 'Профиль табылмады'),
                actionLabel: _t('Обновить', 'Жаңарту'),
                onAction: _reloadProfile,
              );
            }

            if (!_isEditing) _syncControllers(profile);
            return Column(
              children: [
                _ProfileTopHeader(
                  activeTab: _activeTab,
                  isEditing: _isEditing,
                  isSaving: _isSaving,
                  onTabChanged: (tab) => setState(() => _activeTab = tab),
                  onEditTap: () {
                    if (_isSaving || _isUploadingPhoto) return;
                    if (_isEditing) {
                      _syncControllers(profile);
                      setState(() => _isEditing = false);
                    } else {
                      _syncControllers(profile);
                      setState(() => _isEditing = true);
                    }
                  },
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _activeTab == _RestaurantProfileTab.profile
                        ? _buildProfileTab(profile)
                        : RestaurantStatisticsTab(
                            key: ValueKey('statistics_${profile.id}'),
                            restaurantId: profile.id,
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileTab(RestaurantProfileData profile) {
    final selectedBranch = _branches.cast<_RestaurantBranch?>().firstWhere(
          (branch) => branch?.id == _selectedRestaurantId,
          orElse: () => _branches.isEmpty ? null : _branches.first,
        );

    return RefreshIndicator(
      onRefresh: _reloadProfile,
      color: const Color(0xFF489F2A),
      backgroundColor: const Color(0xFF121B2C),
      child: ListView(
        key: const ValueKey('profile_tab'),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          _PhotoCard(
            profile: profile,
            localPreview: _localPhotoPreview,
            cacheBuster: _photoCacheBuster,
            uploading: _isUploadingPhoto,
            onChange: _pickAndUploadPhoto,
          ),
          const SizedBox(height: 12),
          if (_isLoadingBranches || selectedBranch != null)
            _BranchCard(
              branch: selectedBranch,
              branchCount: _branches.length,
              loading: _isLoadingBranches,
              onTap: _showBranchSelector,
            ),
          if (_isLoadingBranches || selectedBranch != null)
            const SizedBox(height: 12),
          _ReadOnlyCard(
            icon: Icons.storefront_rounded,
            title: _t('Название', 'Атауы'),
            value: _displayName(profile),
          ),
          const SizedBox(height: 12),
          _EditableCard(
            icon: Icons.location_on_outlined,
            title: _t('Адрес', 'Мекенжай'),
            value: _displayAddress(profile),
            controller: _addressController,
            enabled: _isEditing && !_isSaving,
            hint: _t('Введите адрес', 'Мекенжайды енгізіңіз'),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          _EditableCard(
            icon: Icons.phone_outlined,
            title: _t('Телефон', 'Телефон'),
            value: _displayPhone(profile),
            controller: _phoneController,
            enabled: _isEditing && !_isSaving,
            hint: '+7 700 000 00 00',
          ),
          const SizedBox(height: 12),
          _EditableCard(
            icon: Icons.access_time_rounded,
            title: _t('Время работы', 'Жұмыс уақыты'),
            value: _displayWorkingHours(profile),
            controller: _workingHoursController,
            enabled: _isEditing && !_isSaving,
            hint: '09:00 - 22:00',
          ),
          const SizedBox(height: 12),
          _StatusCard(status: profile.status),
          if (_isEditing) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            _syncControllers(profile);
                            setState(() => _isEditing = false);
                          },
                    child: Text(_t('Отмена', 'Бас тарту')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSaving ? null : () => _saveProfile(profile),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF489F2A),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_t('Сохранить', 'Сақтау')),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _logout,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: Text(_t('Выйти из аккаунта', 'Аккаунттан шығу')),
          ),
        ],
      ),
    );
  }
}

class _PhotoPreparationException implements Exception {
  const _PhotoPreparationException();
}

class _ProfileTopHeader extends StatelessWidget {
  const _ProfileTopHeader({
    required this.activeTab,
    required this.onTabChanged,
    required this.onEditTap,
    required this.isEditing,
    required this.isSaving,
  });

  final _RestaurantProfileTab activeTab;
  final ValueChanged<_RestaurantProfileTab> onTabChanged;
  final VoidCallback onEditTap;
  final bool isEditing;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF489F2A), Color(0xFF3A7E21)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('Мой ресторан', 'Менің мейрамханам'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: isSaving ? null : onEditTap,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isEditing ? Icons.close_rounded : Icons.edit_outlined,
                        color: Colors.white,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TabButton(
                    text: context.tr('Профиль', 'Профиль'),
                    active: activeTab == _RestaurantProfileTab.profile,
                    onTap: () => onTabChanged(_RestaurantProfileTab.profile),
                  ),
                ),
                Expanded(
                  child: _TabButton(
                    text: context.tr('Статистика', 'Статистика'),
                    active: activeTab == _RestaurantProfileTab.statistics,
                    onTap: () => onTabChanged(_RestaurantProfileTab.statistics),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.text, required this.active, required this.onTap});

  final String text;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? const Color(0xFF489F2A) : Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.profile,
    required this.localPreview,
    required this.cacheBuster,
    required this.uploading,
    required this.onChange,
  });

  final RestaurantProfileData profile;
  final File? localPreview;
  final int cacheBuster;
  final bool uploading;
  final VoidCallback onChange;

  String _remoteUrl() {
    final raw = profile.coverImageUrl?.trim() ?? '';
    if (raw.isNotEmpty) {
      final url = raw.startsWith('http') ? raw : '${AppConfig.baseUrl}$raw';
      return '$url?t=$cacheBuster';
    }
    final legacy = profile.imageUrl?.trim() ?? '';
    return legacy.isEmpty ? '' : '$legacy?t=$cacheBuster';
  }

  @override
  Widget build(BuildContext context) {
    final url = _remoteUrl();
    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: const Color(0xFF131E2D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF22324A)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (localPreview != null)
            Image.file(localPreview!, fit: BoxFit.cover)
          else if (url.isNotEmpty)
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _PhotoPlaceholder(),
            )
          else
            const _PhotoPlaceholder(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0x77000000), Colors.transparent],
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: FilledButton.icon(
              onPressed: uploading ? null : onChange,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF489F2A),
              ),
              icon: uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.photo_library_outlined),
              label: Text(
                uploading
                    ? context.tr('Загрузка...', 'Жүктелуде...')
                    : context.tr('Изменить фото', 'Фотосуретті өзгерту'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF172338),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.image_not_supported_outlined,
              color: Color(0xFF7E8CA3),
              size: 42,
            ),
            const SizedBox(height: 10),
            Text(
              context.tr(
                'Фото ресторана не загружено',
                'Мейрамхана фотосуреті жүктелмеген',
              ),
              style: const TextStyle(color: Color(0xFFA2AEC0)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyCard extends StatelessWidget {
  const _ReadOnlyCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _BaseInfoCard(
      icon: icon,
      title: title,
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EditableCard extends StatelessWidget {
  const _EditableCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.controller,
    required this.enabled,
    required this.hint,
    this.maxLines = 1,
  });

  final IconData icon;
  final String title;
  final String value;
  final TextEditingController controller;
  final bool enabled;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return _BaseInfoCard(
      icon: icon,
      title: title,
      child: enabled
          ? TextField(
              controller: controller,
              maxLines: maxLines,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: const Color(0xFF0E1626),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF2A3A52)),
                ),
              ),
            )
          : Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

class _BaseInfoCard extends StatelessWidget {
  const _BaseInfoCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131E2D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22324A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0x33489F2A),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF65C044)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF7F8BA0),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});
  final String? status;

  @override
  Widget build(BuildContext context) {
    final open = (status ?? '').trim().toUpperCase() == 'OPEN';
    return _BaseInfoCard(
      icon: Icons.radio_button_checked_rounded,
      title: context.tr('Статус ресторана', 'Мейрамхана мәртебесі'),
      child: Text(
        open ? context.tr('Открыт', 'Ашық') : context.tr('Закрыт', 'Жабық'),
        style: TextStyle(
          color: open ? const Color(0xFF65C044) : const Color(0xFFFF6E6E),
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.branch,
    required this.branchCount,
    required this.loading,
    required this.onTap,
  });

  final _RestaurantBranch? branch;
  final int branchCount;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final canChange = branchCount > 1;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: loading || !canChange ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF131E2D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF22324A)),
          ),
          child: Row(
            children: [
              loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.account_tree_outlined,
                      color: Color(0xFF65C044),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Филиал', 'Филиал'),
                      style: const TextStyle(
                        color: Color(0xFF7F8BA0),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loading
                          ? context.tr('Загрузка...', 'Жүктелуде...')
                          : branch?.displayName(context) ??
                              context.tr('Не выбран', 'Таңдалмаған'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (canChange) ...[
                      const SizedBox(height: 3),
                      Text(
                        context.tr(
                          'Нажмите, чтобы сменить филиал',
                          'Филиалды ауыстыру үшін басыңыз',
                        ),
                        style: const TextStyle(
                          color: Color(0xFF93A0B4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (canChange)
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF93A0B4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestaurantBranch {
  const _RestaurantBranch({
    required this.id,
    required this.ordinal,
    this.nameRu,
    this.nameKk,
  });

  final String id;
  final int ordinal;
  final String? nameRu;
  final String? nameKk;

  String displayName(BuildContext context) {
    final primary = context.isKazakh ? nameKk : nameRu;
    final fallback = context.isKazakh ? nameRu : nameKk;
    final first = primary?.trim() ?? '';
    if (first.isNotEmpty) return first;
    final second = fallback?.trim() ?? '';
    if (second.isNotEmpty) return second;
    return '${context.tr('Филиал', 'Филиал')} $ordinal';
  }
}

class _ProfileMessageState extends StatelessWidget {
  const _ProfileMessageState({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF489F2A),
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
