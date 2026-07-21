import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yaleeq_dashboard/app/theme/app_colors.dart';

/// Full-screen overlay shown while the server processes the try-on.
///
/// Features a rotating gradient ring, pulsing icon, rotating fun messages,
/// and a live elapsed-time counter — designed to keep the user engaged
/// during the ~30-60 min CPU processing time.
class GeneratingOverlay extends StatefulWidget {
  const GeneratingOverlay({super.key, required this.onCancel});

  final VoidCallback onCancel;

  @override
  State<GeneratingOverlay> createState() => _GeneratingOverlayState();
}

class _GeneratingOverlayState extends State<GeneratingOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final AnimationController _rotationController;
  late final Timer _messageTimer;
  late final Timer _elapsedTimer;

  int _messageIndex = 0;
  Duration _elapsed = Duration.zero;

  static const _messages = [
    'Preparing your virtual fitting room…',
    'Analyzing the garment details…',
    'Matching the perfect fit…',
    'AI is styling your look…',
    'Adjusting colors and shadows…',
    'Fine-tuning the draping…',
    'Creating photorealistic details…',
    'Almost there, perfecting the look…',
    'Adding final touches…',
    'Your fashion moment is coming…',
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _messageTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % _messages.length;
        });
      }
    });

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsed += const Duration(seconds: 1));
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _messageTimer.cancel();
    _elapsedTimer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xD9000000), // 85 % black
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AnimatedRing(
                  rotationController: _rotationController,
                  scaleAnimation: _scaleAnimation,
                ),
                const SizedBox(height: 32),
                _RotatingMessage(
                  message: _messages[_messageIndex],
                  index: _messageIndex,
                ),
                const SizedBox(height: 16),
                _ElapsedTime(formatted: _formatDuration(_elapsed)),
                const SizedBox(height: 8),
                const Text(
                  'This may take up to 45 minutes on CPU',
                  style: TextStyle(color: AppColors.textHint, fontSize: 12),
                ),
                const SizedBox(height: 32),
                const SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: AppColors.cardFill,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 40),
                TextButton.icon(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancel'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────

class _AnimatedRing extends StatelessWidget {
  const _AnimatedRing({
    required this.rotationController,
    required this.scaleAnimation,
  });

  final AnimationController rotationController;
  final Animation<double> scaleAnimation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: rotationController,
            child: CustomPaint(
              size: const Size(140, 140),
              painter: const _GradientRingPainter(),
            ),
          ),
          ScaleTransition(
            scale: scaleAnimation,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withAlpha(77),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const Icon(
                Icons.checkroom,
                color: AppColors.primaryLight,
                size: 36,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RotatingMessage extends StatelessWidget {
  const _RotatingMessage({required this.message, required this.index});
  final String message;
  final int index;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Text(
        message,
        key: ValueKey(index),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ElapsedTime extends StatelessWidget {
  const _ElapsedTime({required this.formatted});
  final String formatted;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatted,
      style: const TextStyle(
        color: AppColors.textHint,
        fontSize: 28,
        fontWeight: FontWeight.w300,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}

// ── Custom Painter ─────────────────────────────────────────

class _GradientRingPainter extends CustomPainter {
  const _GradientRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final paint = Paint()
      ..shader = const SweepGradient(
        colors: [
          AppColors.primary,
          AppColors.primaryLight,
          AppColors.accent,
          AppColors.primaryLight,
          AppColors.primary,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
