import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/banner_model.dart';
import '../../services/supabase_service.dart';
import '../../theme/theme.dart';

Future<List<BannerItem>> fetchActiveBanners() async {
  final response = await SupabaseService.client
      .from('banners')
      .select()
      .eq('is_active', true)
      .order('sort_order', ascending: true);

  return response
      .map<BannerItem>(
        (row) => BannerItem.fromMap(Map<String, dynamic>.from(row)),
      )
      .where((banner) => banner.isVisibleNow)
      .toList();
}

class BannerSlider extends StatefulWidget {
  const BannerSlider({super.key, required this.onTap});

  final Future<void> Function(BannerItem banner) onTap;

  @override
  State<BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider> {
  final PageController _pageController = PageController();
  List<BannerItem> _banners = [];
  Timer? _timer;
  int _currentIndex = 0;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadBanners() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final banners = await fetchActiveBanners();
      debugPrint('Banner count: ${banners.length}');
      debugPrint(
        'First banner URL: ${banners.isEmpty ? '' : banners.first.imageUrl}',
      );
      if (!mounted) return;
      setState(() {
        _banners = banners;
        _currentIndex = 0;
        _loading = false;
      });
      _startAutoSlide();
    } catch (error, stackTrace) {
      debugPrint('BannerSlider.load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _banners = [];
        _errorMessage = error.toString();
        _loading = false;
      });
    }
  }

  void _startAutoSlide() {
    _timer?.cancel();
    if (_banners.length <= 1) return;

    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_pageController.hasClients || _banners.isEmpty) return;
      final nextIndex = (_currentIndex + 1) % _banners.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_banners.isEmpty) {
      if (_errorMessage != null) {
        return _BannerEmpty(message: 'Không tải được banner');
      }
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _banners.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final banner = _banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: GestureDetector(
                  onTap: () => widget.onTap(banner),
                  child: _BannerSlide(banner: banner),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _BannerDots(count: _banners.length, index: _currentIndex),
      ],
    );
  }
}

class _BannerSlide extends StatelessWidget {
  const _BannerSlide({required this.banner});

  final BannerItem banner;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (banner.imageUrl.trim().isEmpty)
            const _BannerImageFallback()
          else
            CachedNetworkImage(
              imageUrl: banner.imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => const ColoredBox(
                color: AppTheme.surfaceColor,
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) =>
                  const _BannerImageFallback(),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xD91A0A04),
                  Color(0x331A0A04),
                  Color(0xD91A0A04),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (banner.tag.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      banner.tag,
                      style: const TextStyle(
                        color: AppTheme.goldColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  banner.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.lightTextColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (banner.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    banner.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
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

class _BannerDots extends StatelessWidget {
  const _BannerDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (dotIndex) {
        final selected = dotIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: selected ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected ? AppTheme.goldColor : AppTheme.lineColor,
          ),
        );
      }),
    );
  }
}

class _BannerImageFallback extends StatelessWidget {
  const _BannerImageFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppTheme.surfaceColor,
      child: Center(
        child: Icon(Icons.broken_image, color: AppTheme.goldColor, size: 38),
      ),
    );
  }
}

class _BannerEmpty extends StatelessWidget {
  const _BannerEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.lineColor),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedColor),
      ),
    );
  }
}
