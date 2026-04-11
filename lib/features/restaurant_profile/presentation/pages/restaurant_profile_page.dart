import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jetkiz_restaurant/core/config/app_config.dart';
import 'package:jetkiz_restaurant/core/navigation/app_page_route.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/auth/data/auth_storage.dart';
import 'package:jetkiz_restaurant/features/auth/presentation/pages/restaurant_auth_page.dart';
import 'package:jetkiz_restaurant/features/restaurant/data/restaurant_api.dart';
import 'package:jetkiz_restaurant/features/restaurant/domain/restaurant_profile_data.dart';
import 'package:jetkiz_restaurant/features/restaurant_profile/widgets/restaurant_statistics_tab.dart';

// JETKIZ RESTAURANT APP
// Restaurant profile page.
//
// BACKEND:
// - GET /restaurants/me
// - PATCH /restaurants/me
// - POST /restaurants/:id/cover
//
// IMPORTANT:
// Backend upload currently accepts only:
// jpg / jpeg / png / webp
//
// Because gallery/camera may return HEIC/HEIF on some devices,
// selected image is converted to JPG before upload.

class RestaurantProfilePage extends StatefulWidget {
  const RestaurantProfilePage({
    super.key,
    this.hideBottomBar = false,
  });

  final bool hideBottomBar;

  @override
  State<RestaurantProfilePage> createState() => _RestaurantProfilePageState();
}

class _RestaurantProfilePageState extends State<RestaurantProfilePage> {
  late final RestaurantApi _restaurantApi;
  final ImagePicker _imagePicker = ImagePicker();

  Future<RestaurantProfileData>? _profileFuture;

  _RestaurantProfileTab _activeTab = _RestaurantProfileTab.profile;

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _workingHoursController = TextEditingController();

  String? _lastProfileSyncKey;
  File? _localPhotoPreview;
  int _photoCacheBuster = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _restaurantApi = RestaurantApi(ApiClient());
    _profileFuture = _restaurantApi.getMyRestaurant();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _workingHoursController.dispose();
    super.dispose();
  }

  Future<void> _reloadProfile() async {
    setState(() {
      _profileFuture = _restaurantApi.getMyRestaurant();
    });
    await _profileFuture;
  }

  void _syncControllersFromProfile(RestaurantProfileData profile) {
    final syncKey = [
      profile.id,
      profile.phone ?? '',
      profile.address ?? '',
      profile.workingHours ?? '',
      profile.workingHoursFrom ?? '',
      profile.workingHoursTo ?? '',
    ].join('|');

    if (_lastProfileSyncKey == syncKey) {
      return;
    }

    _phoneController.text = profile.phone?.trim() ?? '';
    _addressController.text = profile.address?.trim() ?? '';

    if (profile.workingHours?.trim().isNotEmpty == true) {
      _workingHoursController.text = profile.workingHours!.trim();
    } else if (profile.workingHoursFrom?.trim().isNotEmpty == true &&
        profile.workingHoursTo?.trim().isNotEmpty == true) {
      _workingHoursController.text =
          '${profile.workingHoursFrom!.trim()} - ${profile.workingHoursTo!.trim()}';
    } else {
      _workingHoursController.text = '';
    }

    _lastProfileSyncKey = syncKey;
  }

  void _startEditing(RestaurantProfileData profile) {
    _syncControllersFromProfile(profile);
    setState(() {
      _isEditing = true;
    });
  }

  void _cancelEditing(RestaurantProfileData profile) {
    _syncControllersFromProfile(profile);
    setState(() {
      _isEditing = false;
    });
  }

  Future<void> _saveProfile(RestaurantProfileData profile) async {
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();
    final workingHours = _workingHoursController.text.trim();

    if (address.isEmpty) {
      _showSnackBar('Введите адрес');
      return;
    }

    if (phone.isEmpty) {
      _showSnackBar('Введите телефон');
      return;
    }

    if (workingHours.isEmpty) {
      _showSnackBar('Введите время работы');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedProfile = await _restaurantApi.updateMe(
        address: address,
        phone: phone,
        workingHours: workingHours,
      );

      _syncControllersFromProfile(updatedProfile);

      if (!mounted) return;

      setState(() {
        _isEditing = false;
        _profileFuture = Future.value(updatedProfile);
      });

      await _reloadProfile();

      if (!mounted) return;
      _showSnackBar('Профиль сохранён');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<File> _prepareUploadFile(File originalFile) async {
    final lowerPath = originalFile.path.toLowerCase();

    final alreadySupported =
        lowerPath.endsWith('.jpg') ||
        lowerPath.endsWith('.jpeg') ||
        lowerPath.endsWith('.png') ||
        lowerPath.endsWith('.webp');

    if (alreadySupported) {
      return originalFile;
    }

    final targetPath = '${originalFile.path}_upload.jpg';

    final compressed = await FlutterImageCompress.compressAndGetFile(
      originalFile.absolute.path,
      targetPath,
      format: CompressFormat.jpeg,
      quality: 90,
    );

    if (compressed == null) {
      throw Exception('Не удалось подготовить фото к загрузке');
    }

    return File(compressed.path);
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_isUploadingPhoto) return;

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (pickedFile == null) {
        return;
      }

      final originalFile = File(pickedFile.path);
      final uploadFile = await _prepareUploadFile(originalFile);

      if (!mounted) return;

      setState(() {
        _localPhotoPreview = uploadFile;
        _isUploadingPhoto = true;
      });

      final updatedProfile = await _restaurantApi.uploadRestaurantCover(
        uploadFile,
      );

      if (!mounted) return;

      setState(() {
        _profileFuture = Future.value(updatedProfile);
        _localPhotoPreview = null;
        _photoCacheBuster = DateTime.now().millisecondsSinceEpoch;
      });

      await _reloadProfile();

      if (!mounted) return;

      setState(() {
        _photoCacheBuster = DateTime.now().millisecondsSinceEpoch;
      });

      _showSnackBar('Фото обновлено');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _localPhotoPreview = null;
      });
      _showSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await AuthStorage().clearTokens();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      AppPageRoute<void>(
        page: const RestaurantAuthPage(),
      ),
      (route) => false,
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      appBar: widget.hideBottomBar
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF09111C),
              elevation: 0,
              centerTitle: true,
              title: const Text(
                'Мой ресторан',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      body: SafeArea(
        child: FutureBuilder<RestaurantProfileData>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ошибка загрузки профиля: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _reloadProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF489F2A),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final profile = snapshot.data;
            if (profile == null) {
              return const Center(
                child: Text(
                  'Профиль не найден',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            if (!_isEditing) {
              _syncControllersFromProfile(profile);
            }

            return Column(
              children: [
                _ProfileTopHeader(
                  activeTab: _activeTab,
                  isEditing: _isEditing,
                  isSaving: _isSaving,
                  onTabChanged: (tab) {
                    setState(() => _activeTab = tab);
                  },
                  onEditTap: () {
                    if (_isSaving || _isUploadingPhoto) return;

                    if (_isEditing) {
                      _cancelEditing(profile);
                    } else {
                      _startEditing(profile);
                    }
                  },
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _activeTab == _RestaurantProfileTab.profile
                        ? _ProfileTabView(
                            key: const ValueKey('profile_tab'),
                            profile: profile,
                            onReload: _reloadProfile,
                            isEditing: _isEditing,
                            isSaving: _isSaving,
                            isUploadingPhoto: _isUploadingPhoto,
                            localPhotoPreview: _localPhotoPreview,
                            photoCacheBuster: _photoCacheBuster,
                            phoneController: _phoneController,
                            addressController: _addressController,
                            workingHoursController: _workingHoursController,
                            onCancel: () => _cancelEditing(profile),
                            onSave: () => _saveProfile(profile),
                            onChangePhoto: _pickAndUploadPhoto,
                            onLogout: _logout,
                          )
                        : RestaurantStatisticsTab(
                            key: ValueKey('statistics_tab_${profile.id}'),
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
}

enum _RestaurantProfileTab {
  profile,
  statistics,
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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF489F2A),
            Color(0xFF3A7E21),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332E6A1A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Мой ресторан',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isSaving ? null : onEditTap,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            isEditing ? Icons.close_rounded : Icons.edit_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeaderTabButton(
                    text: 'Профиль',
                    isActive: activeTab == _RestaurantProfileTab.profile,
                    onTap: () => onTabChanged(_RestaurantProfileTab.profile),
                  ),
                ),
                Expanded(
                  child: _HeaderTabButton(
                    text: 'Статистика',
                    isActive: activeTab == _RestaurantProfileTab.statistics,
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

class _HeaderTabButton extends StatelessWidget {
  const _HeaderTabButton({
    required this.text,
    required this.isActive,
    required this.onTap,
  });

  final String text;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: isActive
                ? const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: isActive ? const Color(0xFF489F2A) : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileTabView extends StatelessWidget {
  const _ProfileTabView({
    super.key,
    required this.profile,
    required this.onReload,
    required this.isEditing,
    required this.isSaving,
    required this.isUploadingPhoto,
    required this.localPhotoPreview,
    required this.photoCacheBuster,
    required this.phoneController,
    required this.addressController,
    required this.workingHoursController,
    required this.onCancel,
    required this.onSave,
    required this.onChangePhoto,
    required this.onLogout,
  });

  final RestaurantProfileData profile;
  final Future<void> Function() onReload;
  final bool isEditing;
  final bool isSaving;
  final bool isUploadingPhoto;
  final File? localPhotoPreview;
  final int photoCacheBuster;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController workingHoursController;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final VoidCallback onChangePhoto;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onReload,
      color: const Color(0xFF489F2A),
      backgroundColor: const Color(0xFF121B2C),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          _RestaurantPhotoCard(
            profile: profile,
            localPreviewFile: localPhotoPreview,
            isUploading: isUploadingPhoto,
            onChangePhoto: onChangePhoto,
            cacheBuster: photoCacheBuster,
          ),
          const SizedBox(height: 14),
          _InfoCard(
            icon: Icons.storefront_rounded,
            iconBg: const Color(0x33489F2A),
            iconColor: const Color(0xFF65C044),
            title: 'Название',
            value: _displayName(profile),
            helperText: isEditing
                ? 'Название пока читается только из backend и в этом экране не редактируется'
                : null,
          ),
          const SizedBox(height: 12),
          _EditableInfoCard(
            icon: Icons.location_on_outlined,
            iconBg: const Color(0x332A7BFF),
            iconColor: const Color(0xFF5EA3FF),
            title: 'Адрес',
            controller: addressController,
            value: _displayAddress(profile),
            hintText: 'Введите адрес',
            enabled: isEditing && !isSaving,
            multiLine: true,
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          _EditableInfoCard(
            icon: Icons.phone_outlined,
            iconBg: const Color(0x336C3DF4),
            iconColor: const Color(0xFFA27BFF),
            title: 'Телефон',
            controller: phoneController,
            value: _displayPhone(profile),
            hintText: 'Введите телефон',
            enabled: isEditing && !isSaving,
          ),
          const SizedBox(height: 12),
          _EditableInfoCard(
            icon: Icons.access_time_rounded,
            iconBg: const Color(0x33F08A24),
            iconColor: const Color(0xFFFFA247),
            title: 'Время работы',
            controller: workingHoursController,
            value: _displayWorkingHours(profile),
            hintText: 'Например: 09:00 - 22:00',
            enabled: isEditing && !isSaving,
          ),
          const SizedBox(height: 12),
          _StatusCard(status: profile.status),
          if (isEditing) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSaving ? null : onCancel,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF33445F)),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isSaving ? null : onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF489F2A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Сохранить',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onLogout,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Выйти из аккаунта',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _displayName(RestaurantProfileData profile) {
    if (profile.nameRu.trim().isNotEmpty) return profile.nameRu.trim();
    if (profile.nameKk?.trim().isNotEmpty == true) return profile.nameKk!.trim();
    return 'Без названия';
  }

  static String _displayAddress(RestaurantProfileData profile) {
    if (profile.address?.trim().isNotEmpty == true) return profile.address!.trim();
    return 'Адрес не указан';
  }

  static String _displayPhone(RestaurantProfileData profile) {
    if (profile.phone?.trim().isNotEmpty == true) return profile.phone!.trim();
    return 'Телефон не указан';
  }

  static String _displayWorkingHours(RestaurantProfileData profile) {
    if (profile.workingHours?.trim().isNotEmpty == true) {
      return profile.workingHours!.trim();
    }

    if (profile.workingHoursFrom?.trim().isNotEmpty == true &&
        profile.workingHoursTo?.trim().isNotEmpty == true) {
      return '${profile.workingHoursFrom!.trim()} - ${profile.workingHoursTo!.trim()}';
    }

    return 'Время не указано';
  }
}

class _RestaurantPhotoCard extends StatelessWidget {
  const _RestaurantPhotoCard({
    required this.profile,
    required this.localPreviewFile,
    required this.isUploading,
    required this.onChangePhoto,
    required this.cacheBuster,
  });

  final RestaurantProfileData profile;
  final File? localPreviewFile;
  final bool isUploading;
  final VoidCallback onChangePhoto;
  final int cacheBuster;

  @override
  Widget build(BuildContext context) {
    final remoteImageUrl = _resolveRemoteImage(profile);
    final hasRemoteImage = remoteImageUrl.isNotEmpty;
    final hasLocalPreview = localPreviewFile != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF172338),
            Color(0xFF0F1829),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF22324A),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            if (hasLocalPreview)
              Image.file(
                localPreviewFile!,
                height: 186,
                width: double.infinity,
                fit: BoxFit.cover,
              )
            else if (hasRemoteImage)
              Image.network(
                remoteImageUrl,
                height: 186,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) {
                  return const _PhotoPlaceholder();
                },
              )
            else
              const _PhotoPlaceholder(),
            Container(
              height: 186,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0x66000000),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: ElevatedButton.icon(
                onPressed: isUploading ? null : onChangePhoto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF489F2A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(
                  isUploading ? 'Загрузка...' : 'Изменить фото',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveRemoteImage(RestaurantProfileData profile) {
    final rawImagePath = (profile.coverImageUrl ?? '').trim();

    if (rawImagePath.isNotEmpty) {
      final imageUrl = rawImagePath.startsWith('http')
          ? rawImagePath
          : '${AppConfig.baseUrl}$rawImagePath';

      return '$imageUrl?t=$cacheBuster';
    }

    final legacy = profile.imageUrl?.trim() ?? '';
    if (legacy.isNotEmpty) {
      return '$legacy?t=$cacheBuster';
    }

    return '';
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 186,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B2A43),
            Color(0xFF0E1626),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.10),
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.image_not_supported_outlined,
              color: Color(0xFF7E8CA3),
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Фото ресторана не загружено',
            style: TextStyle(
              color: Color(0xFFA2AEC0),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF489F2A),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Добавить фото',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.value,
    this.multiLine = false,
    this.helperText,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String value;
  final bool multiLine;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF151F32),
            Color(0xFF0D1524),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF22324A),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: iconColor.withOpacity(0.28),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
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
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: multiLine ? 14 : 15,
                    fontWeight: FontWeight.w700,
                    height: multiLine ? 1.35 : 1.2,
                  ),
                ),
                if (helperText?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    helperText!.trim(),
                    style: const TextStyle(
                      color: Color(0xFF93A0B4),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableInfoCard extends StatelessWidget {
  const _EditableInfoCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.controller,
    required this.value,
    required this.hintText,
    required this.enabled,
    this.multiLine = false,
    this.minLines,
    this.maxLines = 1,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final TextEditingController controller;
  final String value;
  final String hintText;
  final bool enabled;
  final bool multiLine;
  final int? minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final isEditMode = enabled;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF151F32),
            Color(0xFF0D1524),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF22324A),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: iconColor.withOpacity(0.28),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
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
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                if (isEditMode)
                  TextField(
                    controller: controller,
                    enabled: enabled,
                    minLines: minLines,
                    maxLines: maxLines,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: const TextStyle(
                        color: Color(0xFF6F7C91),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0E1626),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF2A3A52),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF489F2A),
                          width: 1.4,
                        ),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF2A3A52),
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: multiLine ? 14 : 15,
                      fontWeight: FontWeight.w700,
                      height: multiLine ? 1.35 : 1.2,
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

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.status,
  });

  final String? status;

  @override
  Widget build(BuildContext context) {
    final isOpen = (status ?? '').trim().toUpperCase() == 'OPEN';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOpen
              ? [
                  const Color(0x1A489F2A),
                  const Color(0x143A7E21),
                ]
              : [
                  const Color(0x1AF04444),
                  const Color(0x14B72F2F),
                ],
        ),
        border: Border.all(
          color: isOpen
              ? const Color(0x55489F2A)
              : const Color(0x55E45252),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isOpen
                  ? const Color(0x33489F2A)
                  : const Color(0x33E45252),
              shape: BoxShape.circle,
              border: Border.all(
                color: isOpen
                    ? const Color(0x66489F2A)
                    : const Color(0x66E45252),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.radio_button_checked_rounded,
              color: isOpen
                  ? const Color(0xFF65C044)
                  : const Color(0xFFFF6E6E),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Статус ресторана',
              style: TextStyle(
                color: Color(0xFF7F8BA0),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: isOpen
                      ? const Color(0xFF65C044)
                      : const Color(0xFFFF6E6E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isOpen ? 'Открыт' : 'Закрыт',
                style: TextStyle(
                  color: isOpen
                      ? const Color(0xFF65C044)
                      : const Color(0xFFFF6E6E),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}