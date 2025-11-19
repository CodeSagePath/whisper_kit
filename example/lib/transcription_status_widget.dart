import "dart:async";
import "dart:math" as math;

import "package:flutter/material.dart";

class TranscriptionStatusWidget extends StatefulWidget {
  const TranscriptionStatusWidget({
    super.key,
    required this.isActive,
    this.duration = Duration.zero,
  });

  final bool isActive;
  final Duration duration;

  @override
  State<TranscriptionStatusWidget> createState() =>
      _TranscriptionStatusWidgetState();
}

class _TranscriptionStatusWidgetState extends State<TranscriptionStatusWidget>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _dotsController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<int> _dotsAnimation;

  Timer? _timer;
  Duration _elapsedTime = Duration.zero;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _dotsAnimation = StepTween(begin: 1, end: 4).animate(
      CurvedAnimation(
        parent: _dotsController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isActive) {
      _startAnimations();
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(TranscriptionStatusWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _startAnimations();
        _startTimer();
      } else {
        _stopAnimations();
        _stopTimer();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _slideController.dispose();
    _fadeController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  void _startAnimations() {
    _slideController.forward();
    _fadeController.forward();
    _dotsController.repeat();
  }

  void _stopAnimations() {
    _slideController.reverse();
    _fadeController.reverse();
    _dotsController.stop();
    _dotsController.reset();
  }

  void _startTimer() {
    _elapsedTime = Duration.zero;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {
        _elapsedTime =
            Duration(milliseconds: _elapsedTime.inMilliseconds + 100);
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _elapsedTime = Duration.zero;
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  String _getDots() {
    return "." * _dotsAnimation.value;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0F3460).withValues(alpha: 0.9),
                const Color(0xFF16213E).withValues(alpha: 0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE94560).withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE94560).withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _buildWaveAnimation(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedBuilder(
                          animation: _dotsAnimation,
                          builder: (context, child) {
                            return Text(
                              "Transcribing ${_getDots()}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Processing audio with AI model",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildProgressBar(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Elapsed time",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _formatDuration(_elapsedTime),
                    style: TextStyle(
                      color: const Color(0xFFE94560).withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaveAnimation() {
    return SizedBox(
      width: 40,
      height: 40,
      child: AnimatedBuilder(
        animation: _dotsController,
        builder: (context, child) {
          return CustomPaint(
            painter: WavePainter(_dotsController.value),
          );
        },
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
      child: AnimatedBuilder(
        animation: _fadeController,
        builder: (context, child) {
          return FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _fadeAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE94560),
                    const Color(0xFFE94560).withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        },
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;

  WavePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFFE94560).withValues(alpha: 0.8)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final angle = (animationValue + i * 0.3) * 2 * math.pi;
      final x = center.dx + radius * 0.8 * math.cos(angle);
      final y = center.dy + radius * 0.8 * math.sin(angle);

      final waveRadius =
          3 + i * 2 + math.sin(animationValue * 2 * math.pi + i) * 2;

      canvas.drawCircle(
        Offset(x, y),
        waveRadius,
        paint,
      );
    }

    // Center dot
    paint.color = Colors.white;
    canvas.drawCircle(
      center,
      3,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
