import 'package:flutter/material.dart';
import 'package:jetkiz_restaurant/core/config/app_config.dart';
import 'package:jetkiz_restaurant/core/localization/app_locale_controller.dart';
import 'package:jetkiz_restaurant/core/network/api_client.dart';
import 'package:jetkiz_restaurant/features/reviews/data/restaurant_reviews_api.dart';
import 'package:jetkiz_restaurant/features/reviews/domain/restaurant_review.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

class RestaurantReviewsPage extends StatefulWidget {
  const RestaurantReviewsPage({
    super.key,
    required this.restaurantId,
  });

  final String restaurantId;

  @override
  State<RestaurantReviewsPage> createState() => _RestaurantReviewsPageState();
}

class _RestaurantReviewsPageState extends State<RestaurantReviewsPage> {
  static const int _pageSize = 20;

  late final RestaurantReviewsApi _api;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  String? _error;
  List<RestaurantReview> _items = const <RestaurantReview>[];
  ReviewsMeta _meta = const ReviewsMeta(page: 1, limit: _pageSize, total: 0);
  final Set<String> _mutatingReviewIds = <String>{};

  String _t(String ru, String kk) => context.tr(ru, kk);

  @override
  void initState() {
    super.initState();
    _api = RestaurantReviewsApi(ApiClient.instance);
    _load();
  }

  String _safeError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    if (raw.isEmpty ||
        raw.length > 180 ||
        lower.contains('dio') ||
        lower.contains('socket') ||
        lower.contains('exception') ||
        lower.contains('backend') ||
        lower.contains('api') ||
        lower.contains('endpoint') ||
        lower.contains('status code') ||
        lower.contains('http') ||
        lower.contains('некорректный ответ') ||
        lower.contains('сервер не вернул')) {
      return _t(
        'Не удалось выполнить действие. Проверьте интернет и повторите.',
        'Әрекетті орындау мүмкін болмады. Интернетті тексеріп, қайталаңыз.',
      );
    }
    return raw;
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isRefreshing = true;
        _error = null;
      });
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final result = await _api.getRestaurantReviews(
        restaurantId: widget.restaurantId,
        page: 1,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _meta = result.meta;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _safeError(error));
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_meta.hasMore) return;
    final nextPage = _meta.page + 1;
    setState(() => _isLoadingMore = true);

    try {
      final result = await _api.getRestaurantReviews(
        restaurantId: widget.restaurantId,
        page: nextPage,
        limit: _pageSize,
      );
      if (!mounted) return;
      final seen = _items.map((item) => item.id).toSet();
      setState(() {
        _items = <RestaurantReview>[
          ..._items,
          ...result.items.where((item) => seen.add(item.id)),
        ];
        _meta = result.meta;
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage(_safeError(error));
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _editResponse(RestaurantReview review) async {
    if (_mutatingReviewIds.contains(review.id)) return;
    final controller = TextEditingController(
      text: review.response?.text?.trim() ?? '',
    );

    final responseText = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final canSave = controller.text.trim().isNotEmpty;
          return AlertDialog(
            backgroundColor: const Color(0xFF111827),
            title: Text(
              review.response == null
                  ? _t('Ответить на отзыв', 'Пікірге жауап беру')
                  : _t('Изменить ответ', 'Жауапты өзгерту'),
              style: const TextStyle(color: Colors.white),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              maxLength: 3000,
              onChanged: (_) => setDialogState(() {}),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: _t('Напишите ответ клиенту', 'Клиентке жауап жазыңыз'),
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFF0B1220),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF65C044)),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(_t('Отмена', 'Бас тарту')),
              ),
              FilledButton(
                onPressed: canSave
                    ? () => Navigator.of(dialogContext).pop(controller.text.trim())
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF489F2A),
                ),
                child: Text(_t('Сохранить', 'Сақтау')),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();

    if (responseText == null || responseText.trim().isEmpty || !mounted) return;
    setState(() => _mutatingReviewIds.add(review.id));
    try {
      final savedResponse = await _api.saveResponse(
        reviewId: review.id,
        text: responseText,
      );
      if (!mounted) return;
      _replaceResponse(review.id, savedResponse);
      _showMessage(
        review.response == null
            ? _t('Ответ опубликован', 'Жауап жарияланды')
            : _t('Ответ обновлён', 'Жауап жаңартылды'),
      );
    } catch (error) {
      if (mounted) _showMessage(_safeError(error));
    } finally {
      if (mounted) setState(() => _mutatingReviewIds.remove(review.id));
    }
  }

  Future<void> _deleteResponse(RestaurantReview review) async {
    if (review.response == null || _mutatingReviewIds.contains(review.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text(
          _t('Удалить ответ?', 'Жауапты жою керек пе?'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          _t(
            'Ответ ресторана будет удалён из отзыва.',
            'Мейрамхананың жауабы пікірден жойылады.',
          ),
          style: const TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_t('Отмена', 'Бас тарту')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: Text(_t('Удалить', 'Жою')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _mutatingReviewIds.add(review.id));
    try {
      await _api.deleteResponse(reviewId: review.id);
      if (!mounted) return;
      _replaceResponse(review.id, null);
      _showMessage(_t('Ответ удалён', 'Жауап жойылды'));
    } catch (error) {
      if (mounted) _showMessage(_safeError(error));
    } finally {
      if (mounted) setState(() => _mutatingReviewIds.remove(review.id));
    }
  }

  void _replaceResponse(String reviewId, ReviewResponse? response) {
    setState(() {
      _items = _items
          .map(
            (item) =>
                item.id == reviewId ? item.withResponse(response) : item,
          )
          .toList(growable: false);
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09111C),
        elevation: 0,
        centerTitle: true,
        title: Text(
          _t('Отзывы', 'Пікірлер'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading && !_isRefreshing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _t(
                  'Не удалось загрузить отзывы. Проверьте интернет и повторите.',
                  'Пікірлерді жүктеу мүмкін болмады. Интернетті тексеріп, қайталаңыз.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _load,
                child: Text(_t('Повторить', 'Қайталау')),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        color: const Color(0xFF489F2A),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 140),
            Center(
              child: Text(
                _t('Пока нет отзывов', 'Әзірге пікір жоқ'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      color: const Color(0xFF489F2A),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        itemCount: _items.length + (_meta.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return Center(
              child: OutlinedButton.icon(
                onPressed: _isLoadingMore ? null : _loadMore,
                icon: _isLoadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(
                  _isLoadingMore
                      ? _t('Загрузка…', 'Жүктелуде…')
                      : _t('Показать ещё', 'Тағы көрсету'),
                ),
              ),
            );
          }

          final item = _items[index];
          return _ReviewCard(
            review: item,
            isBusy: _mutatingReviewIds.contains(item.id),
            onReply: () => _editResponse(item),
            onEditResponse: () => _editResponse(item),
            onDeleteResponse: () => _deleteResponse(item),
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.isBusy,
    required this.onReply,
    required this.onEditResponse,
    required this.onDeleteResponse,
  });

  final RestaurantReview review;
  final bool isBusy;
  final VoidCallback onReply;
  final VoidCallback onEditResponse;
  final VoidCallback onDeleteResponse;

  @override
  Widget build(BuildContext context) {
    final userName = review.userName == 'Пользователь'
        ? context.tr('Пользователь', 'Пайдаланушы')
        : review.userName;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF151F32), Color(0xFF0D1524)],
        ),
        border: Border.all(color: const Color(0xFF22324A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(imageUrl: review.userAvatar),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (index) => Icon(
                            index < review.rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 18,
                            color: const Color(0xFFFFC107),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(review.createdAt),
                          style: const TextStyle(
                            color: Color(0xFF93A0B4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((review.text ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review.text!.trim(),
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.45),
            ),
          ],
          if (review.media.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ReviewMediaPreview(media: review.media),
          ],
          if (review.reactionsSummary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: review.reactionsSummary.entries
                  .map(
                    (entry) => _ReactionChip(
                      label: _reactionEmoji(entry.key),
                      count: entry.value,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (review.response != null && review.response!.hasContent) ...[
            const SizedBox(height: 14),
            _ResponseBlock(
              response: review.response!,
              isBusy: isBusy,
              onEdit: onEditResponse,
              onDelete: onDeleteResponse,
            ),
          ] else ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: isBusy ? null : onReply,
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.reply_rounded),
              label: Text(context.tr('Ответить от ресторана', 'Мейрамхана атынан жауап беру')),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF65C044)),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  static String _reactionEmoji(String type) {
    switch (type) {
      case 'LIKE':
        return '👍';
      case 'LOVE':
        return '❤️';
      case 'FIRE':
        return '🔥';
      case 'USEFUL':
        return '💡';
      case 'YUMMY':
        return '😍';
      default:
        return '✨';
    }
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final absolute = _toAbsoluteUrl(imageUrl);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF22324A),
        borderRadius: BorderRadius.circular(999),
      ),
      clipBehavior: Clip.antiAlias,
      child: absolute == null
          ? const Icon(Icons.person_rounded, color: Colors.white70, size: 20)
          : Image.network(
              absolute,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.person_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ),
    );
  }
}

class _ReviewMediaPreview extends StatelessWidget {
  const _ReviewMediaPreview({required this.media});
  final List<ReviewMedia> media;

  @override
  Widget build(BuildContext context) {
    final images = media.where((e) => e.isImage).toList(growable: false);
    final videos = media.where((e) => e.isVideo).toList(growable: false);
    final audios = media.where((e) => e.isAudio).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          GridView.builder(
            itemCount: images.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (_, index) {
              final url = _toAbsoluteUrl(images[index].url);
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Material(
                  color: const Color(0xFF1E2A40),
                  child: InkWell(
                    onTap: url == null
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => _ImageViewerPage(
                                  imageUrls: images
                                      .map((e) => _toAbsoluteUrl(e.url))
                                      .whereType<String>()
                                      .toList(growable: false),
                                  initialIndex: index,
                                ),
                              ),
                            ),
                    child: url == null
                        ? const Icon(Icons.broken_image_outlined, color: Colors.white70)
                        : Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white70,
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        if (videos.isNotEmpty) ...[
          if (images.isNotEmpty) const SizedBox(height: 10),
          ...videos.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _VideoReviewPlayer(media: item),
            ),
          ),
        ],
        if (audios.isNotEmpty) ...[
          if (images.isNotEmpty || videos.isNotEmpty) const SizedBox(height: 2),
          ...audios.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AudioReviewPlayer(media: item),
            ),
          ),
        ],
      ],
    );
  }
}

class _VideoReviewPlayer extends StatefulWidget {
  const _VideoReviewPlayer({required this.media});
  final ReviewMedia media;

  @override
  State<_VideoReviewPlayer> createState() => _VideoReviewPlayerState();
}

class _VideoReviewPlayerState extends State<_VideoReviewPlayer> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final url = _toAbsoluteUrl(widget.media.url);
    if (url == null) {
      setState(() {
        _isLoading = false;
        _error = context.tr('Видео недоступно', 'Видео қолжетімсіз');
      });
      return;
    }
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = context.tr('Не удалось загрузить видео', 'Видеоны жүктеу мүмкін болмады');
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) return;
    controller.value.isPlaying ? await controller.pause() : await controller.play();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final preview = _toAbsoluteUrl(widget.media.previewUrl ?? widget.media.url);
    final controller = _controller;
    final aspect = controller != null && controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 16 / 9;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF111B2B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF22324A)),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: aspect,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (controller != null)
                    VideoPlayer(controller)
                  else if (preview != null)
                    Image.network(
                      preview,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFF1E2A40),
                        child: Icon(Icons.videocam_outlined, color: Colors.white70, size: 40),
                      ),
                    )
                  else
                    const ColoredBox(
                      color: Color(0xFF1E2A40),
                      child: Icon(Icons.videocam_outlined, color: Colors.white70, size: 40),
                    ),
                  if (_isLoading)
                    const ColoredBox(
                      color: Colors.black26,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_error != null)
                    ColoredBox(
                      color: Colors.black54,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    )
                  else if (controller != null)
                    Center(
                      child: IconButton.filled(
                        onPressed: _togglePlay,
                        iconSize: 34,
                        icon: Icon(
                          controller.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.tr('Видео-отзыв', 'Видео-пікір'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          if (controller != null)
            VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              padding: const EdgeInsets.only(top: 8),
              colors: const VideoProgressColors(
                playedColor: Color(0xFF65C044),
                backgroundColor: Colors.white24,
                bufferedColor: Colors.white38,
              ),
            ),
        ],
      ),
    );
  }
}

class _AudioReviewPlayer extends StatefulWidget {
  const _AudioReviewPlayer({required this.media});
  final ReviewMedia media;

  @override
  State<_AudioReviewPlayer> createState() => _AudioReviewPlayerState();
}

class _AudioReviewPlayerState extends State<_AudioReviewPlayer> {
  late final AudioPlayer _player;
  bool _isLoading = true;
  String? _error;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.durationStream.listen((value) {
      if (mounted) setState(() => _duration = value ?? Duration.zero);
    });
    _player.positionStream.listen((value) {
      if (mounted) setState(() => _position = value);
    });
    _player.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing);
    });
    _init();
  }

  Future<void> _init() async {
    final url = _toAbsoluteUrl(widget.media.url);
    if (url == null) {
      setState(() {
        _isLoading = false;
        _error = context.tr('Аудио недоступно', 'Аудио қолжетімсіз');
      });
      return;
    }
    try {
      await _player.setUrl(url);
      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = context.tr('Не удалось загрузить аудио', 'Аудионы жүктеу мүмкін болмады');
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = _duration.inMilliseconds <= 0 ? 1 : _duration.inMilliseconds;
    final currentMs = _position.inMilliseconds.clamp(0, maxMs).toDouble();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111B2B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF22324A)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _isLoading || _error != null
                    ? null
                    : () async {
                        _isPlaying ? await _player.pause() : await _player.play();
                      },
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('Аудио-отзыв', 'Аудио-пікір'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                _formatDuration(_position),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ] else ...[
            Slider(
              value: currentMs,
              min: 0,
              max: maxMs.toDouble(),
              activeColor: const Color(0xFF65C044),
              inactiveColor: Colors.white24,
              onChanged: _isLoading
                  ? null
                  : (value) => _player.seek(Duration(milliseconds: value.round())),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_position), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                Text(_formatDuration(_duration), style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDuration(Duration value) {
    final total = value.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _ResponseBlock extends StatelessWidget {
  const _ResponseBlock({
    required this.response,
    required this.isBusy,
    required this.onEdit,
    required this.onDelete,
  });

  final ReviewResponse response;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x1426A65B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x55489F2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Ответ ресторана', 'Мейрамхана жауабы'),
                  style: const TextStyle(
                    color: Color(0xFF65C044),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isBusy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: context.tr('Изменить ответ', 'Жауапты өзгерту'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF93A0B4), size: 19),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: context.tr('Удалить ответ', 'Жауапты жою'),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF7C7C), size: 19),
                ),
              ],
            ],
          ),
          if ((response.text ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              response.text!.trim(),
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF111B2B),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF22324A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Text(label), const SizedBox(width: 6), Text('$count')],
      ),
    );
  }
}

class _ImageViewerPage extends StatefulWidget {
  const _ImageViewerPage({required this.imageUrls, required this.initialIndex});
  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.imageUrls.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / $total'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: total,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (_, index) => InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Center(
            child: Image.network(
              widget.imageUrls[index],
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white70,
                size: 40,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? _toAbsoluteUrl(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  if (value.startsWith('/')) return '${AppConfig.baseUrl}$value';
  return '${AppConfig.baseUrl}/$value';
}
