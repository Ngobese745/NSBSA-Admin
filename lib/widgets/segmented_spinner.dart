import 'dart:math' as math;
import 'package:flutter/material.dart';

class SegmentedSpinner extends StatefulWidget {
  final double size;
  final double strokeWidth;
  
  const SegmentedSpinner({
    Key? key,
    this.size = 64.0,
    this.strokeWidth = 2.0,
  }) : super(key: key);

  @override
  State<SegmentedSpinner> createState() => _SegmentedSpinnerState();
}

class _SegmentedSpinnerState extends State<SegmentedSpinner> with TickerProviderStateMixin {
  late AnimationController _outerController;
  late AnimationController _innerController;

  @override
  void initState() {
    super.initState();
    _outerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    _innerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _outerController.dispose();
    _innerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Ring
          AnimatedBuilder(
            animation: _outerController,
            builder: (_, child) {
              return Transform.rotate(
                angle: _outerController.value * 2 * math.pi,
                child: CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _RingPainter(
                    strokeWidth: widget.strokeWidth,
                    startColor: const Color.fromRGBO(212, 175, 55, 0.8),
                    endColor: const Color.fromRGBO(212, 175, 55, 0.2),
                    gradientAngle: math.pi / 2, // top to bottom
                  ),
                ),
              );
            },
          ),
          // Inner Ring
          AnimatedBuilder(
            animation: _innerController,
            builder: (_, child) {
              return Transform.rotate(
                // Reverse rotation
                angle: -_innerController.value * 2 * math.pi,
                child: CustomPaint(
                  size: Size(widget.size - 16, widget.size - 16),
                  painter: _RingPainter(
                    strokeWidth: widget.strokeWidth,
                    startColor: const Color.fromRGBO(255, 255, 255, 0.5),
                    endColor: const Color.fromRGBO(255, 255, 255, 0.1),
                    gradientAngle: 0, // left to right
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double strokeWidth;
  final Color startColor;
  final Color endColor;
  final double gradientAngle;

  _RingPainter({
    required this.strokeWidth,
    required this.startColor,
    required this.endColor,
    required this.gradientAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    // Instead of using sweep gradient which has a sharp edge,
    // we use a linear gradient matching the border-top-color / border-bottom-color css behavior.
    final rect = Rect.fromCircle(center: center, radius: radius);
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
      
    // Create a smooth linear gradient. 
    // If gradientAngle is pi/2, it's top to bottom
    final offset1 = Offset(
      center.dx + radius * math.cos(gradientAngle - math.pi/2),
      center.dy + radius * math.sin(gradientAngle - math.pi/2),
    );
    final offset2 = Offset(
      center.dx + radius * math.cos(gradientAngle + math.pi/2),
      center.dy + radius * math.sin(gradientAngle + math.pi/2),
    );
      
    paint.shader = LinearGradient(
      colors: [startColor, endColor],
      begin: Alignment(
        (offset1.dx - center.dx) / radius,
        (offset1.dy - center.dy) / radius,
      ),
      end: Alignment(
        (offset2.dx - center.dx) / radius,
        (offset2.dy - center.dy) / radius,
      ),
    ).createShader(rect);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.strokeWidth != strokeWidth ||
           oldDelegate.startColor != startColor ||
           oldDelegate.endColor != endColor ||
           oldDelegate.gradientAngle != gradientAngle;
  }
}
