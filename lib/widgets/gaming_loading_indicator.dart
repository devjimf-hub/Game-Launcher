import 'package:flutter/material.dart';
import 'dart:math' as math;

class GamingLoadingIndicator extends StatefulWidget {
  const GamingLoadingIndicator({super.key});

  @override
  State<GamingLoadingIndicator> createState() => _GamingLoadingIndicatorState();
}

class _GamingLoadingIndicatorState extends State<GamingLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Delay animation start until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated loading ring
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer ring
                    Transform.rotate(
                      angle: _controller.value * 2 * math.pi,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF00D4FF).withOpacity(0.3),
                            width: 3,
                          ),
                        ),
                        child: CustomPaint(
                          painter: _ArcPainter(
                            progress: _controller.value,
                            color: const Color(0xFF00D4FF),
                          ),
                        ),
                      ),
                    ),
                    // Inner ring (counter-rotate)
                    Transform.rotate(
                      angle: -_controller.value * 2 * math.pi * 1.5,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF9D4EDD).withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: CustomPaint(
                          painter: _ArcPainter(
                            progress: _controller.value,
                            color: const Color(0xFF9D4EDD),
                            startAngle: math.pi,
                          ),
                        ),
                      ),
                    ),
                    // Center icon
                    Icon(
                      Icons.gamepad,
                      size: 24,
                      color: Color.lerp(
                        const Color(0xFF00D4FF),
                        const Color(0xFF9D4EDD),
                        _controller.value,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Loading text with shimmer
              ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: const [
                      Color(0xFF00D4FF),
                      Color(0xFF9D4EDD),
                      Color(0xFF00D4FF),
                    ],
                    stops: [
                      (_controller.value - 0.3).clamp(0.0, 1.0),
                      _controller.value,
                      (_controller.value + 0.3).clamp(0.0, 1.0),
                    ],
                  ).createShader(bounds);
                },
                child: const Text(
                  "LOADING",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8.0,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double startAngle;

  _ArcPainter({
    required this.progress,
    required this.color,
    this.startAngle = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawArc(rect, startAngle, math.pi * 0.7, false, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
