import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

import '../l10n/app_strings.dart';
import '../services/plant_service.dart';
import '../theme/app_colors.dart';
import 'root_shell.dart';

/// Full-bleed live camera tab — stream ကို အပြည့်ပြပြီး အပေါ်မှာ
/// frosted-glass overlay တွေနဲ့ status/sensor အချက်အလက်တွေ တင်ပြတယ်။
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final PlantService _service = PlantService.instance;

  // Stream ကို reload လုပ်ချင်တဲ့အခါ Mjpeg widget အသစ်ဖန်တီးဖို့ key ပြောင်းတယ်။
  int _streamAttempt = 0;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final s = AppLocale.of(context);

    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        return DecoratedBox(
          decoration: const BoxDecoration(color: CupertinoColors.black),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Mjpeg(
                key: ValueKey('${_service.streamUrl}#$_streamAttempt'),
                isLive: true,
                stream: _service.streamUrl,
                error: (context, error, stack) => _StreamError(host: _service.host, onRetry: () => setState(() => _streamAttempt++)),
              ),
              // အပေါ်/အောက် နှစ်ဖက်လုံးမှာ overlay စာလုံးတွေ ဖတ်ရလွယ်အောင် gradient scrim
              const Positioned.fill(child: IgnorePointer(child: _Scrim())),
              Positioned(
                top: topInset + 12,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    _LiveBadge(label: s.live),
                    const Spacer(),
                    _GlassPill(
                      onTap: () => setState(() => _streamAttempt++),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.arrow_clockwise, size: 15, color: CupertinoColors.white),
                          const SizedBox(width: 6),
                          Text(
                            s.reload,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CupertinoColors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: kNavBarClearance,
                child: _OverlayStats(service: _service, strings: s),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            CupertinoColors.black.withValues(alpha: 0.45),
            const Color(0x00000000),
            const Color(0x00000000),
            CupertinoColors.black.withValues(alpha: 0.55),
          ],
          stops: const [0, 0.25, 0.6, 1],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return _GlassPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Dot(),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: CupertinoColors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
    );
  }
}

/// အောက်ခြေမှာ ပြတဲ့ sensor အကျဉ်းချုပ် glass card။
class _OverlayStats extends StatelessWidget {
  const _OverlayStats({required this.service, required this.strings});

  final PlantService service;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: CupertinoColors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CupertinoColors.white.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(service.statusIcon, size: 16, color: service.statusColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      strings.verdictHeadline(service.verdict),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CupertinoColors.white),
                    ),
                  ),
                  Text(
                    strings.lastUpdatedLabel(service.lastUpdated),
                    style: TextStyle(fontSize: 11, color: CupertinoColors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MiniStat(icon: CupertinoIcons.thermometer, value: '${service.temp.toStringAsFixed(1)}°C', color: AppColors.orange),
                  _MiniStat(icon: CupertinoIcons.drop, value: '${service.humid.toStringAsFixed(0)}%', color: AppColors.blue),
                  _MiniStat(icon: CupertinoIcons.leaf_arrow_circlepath, value: service.needsWater ? 'Dry' : 'Moist', color: AppColors.teal),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.value, required this.color});

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CupertinoColors.white),
          ),
        ],
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: CupertinoColors.black.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CupertinoColors.white.withValues(alpha: 0.18)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _StreamError extends StatelessWidget {
  const _StreamError({required this.host, required this.onRetry});

  final String host;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.videocam_circle, color: CupertinoColors.white, size: 52),
            const SizedBox(height: 12),
            const Text(
              'Camera stream disconnected',
              style: TextStyle(color: CupertinoColors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'No video from $host. Check that the ESP32-CAM is powered on and on the same network.',
              textAlign: TextAlign.center,
              style: TextStyle(color: CupertinoColors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 18),
            CupertinoButton(
              color: AppColors.blue,
              borderRadius: BorderRadius.circular(14),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              onPressed: onRetry,
              child: const Text('Try again', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
