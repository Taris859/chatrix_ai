import 'dart:math';
import 'package:flutter/material.dart';
import '../models/scene.dart';

class ParticleData {
  final double depth;
  final double baseX;
  final double baseY;
  final double speed;
  final double length;
  final double thickness;
  final double twinkleSpeed;
  final double swaySpeed;
  final double randomOffset;

  ParticleData({
    required this.depth,
    required this.baseX,
    required this.baseY,
    required this.speed,
    required this.length,
    required this.thickness,
    required this.twinkleSpeed,
    required this.swaySpeed,
    required this.randomOffset,
  });
}

class ParticleBackground extends StatefulWidget {
  final ChatScene scene;

  const ParticleBackground({Key? key, required this.scene}) : super(key: key);

  @override
  _ParticleBackgroundState createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<ParticleData> _particles;

  @override
  void initState() {
    super.initState();
    _generateParticles();
    // High-performance continuous animation loop slowed down for late-night visual comfort
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 35))..repeat();
  }

  @override
  void didUpdateWidget(ParticleBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scene.particleType != widget.scene.particleType) {
      _generateParticles();
    }
  }

  void _generateParticles() {
    final random = Random(2026);
    int count = 45;
    if (widget.scene.particleType == ParticleType.fog) {
      count = 5;
    } else if (widget.scene.particleType == ParticleType.neon) {
      count = 22;
    } else if (widget.scene.particleType == ParticleType.none) {
      count = 0;
    }

    _particles = List.generate(count, (index) {
      double depth = random.nextDouble();
      return ParticleData(
        depth: depth,
        baseX: random.nextDouble(),
        baseY: random.nextDouble(),
        speed: 1.0 + depth * 1.5,
        length: 12.0 + depth * 20.0,
        thickness: 0.5 + depth * 1.5,
        twinkleSpeed: 2.0 + random.nextDouble() * 4.0,
        swaySpeed: 1.0 + random.nextDouble() * 2.0,
        randomOffset: random.nextDouble() * 100.0,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(seconds: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: widget.scene.backgroundGradient,
        ),
      ),
      child: Stack(
        children: [
          // Subtle vignette overlay for dark luxury feel
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.4),
                ],
              ),
            ),
          ),
          // Particle layer
          if (widget.scene.particleType != ParticleType.none)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _CinematicParticlePainter(
                    progress: _controller.value,
                    particleType: widget.scene.particleType,
                    color: widget.scene.accentColor,
                    particles: _particles,
                  ),
                  size: Size.infinite,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CinematicParticlePainter extends CustomPainter {
  final double progress;
  final ParticleType particleType;
  final Color color;
  final List<ParticleData> particles;

  _CinematicParticlePainter({
    required this.progress,
    required this.particleType,
    required this.color,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    if (particleType == ParticleType.rain) {
      // 3D Parallax Rainstreaks
      paint.style = PaintingStyle.stroke;
      for (final p in particles) {
        double x = p.baseX * size.width;
        double y = ((p.baseY + progress * p.speed) % 1.0) * size.height;
        
        paint.color = color.withOpacity(0.08 + p.depth * 0.3);
        paint.strokeWidth = p.thickness;
        
        // Slight organic slant (as if affected by a gentle breeze)
        canvas.drawLine(Offset(x, y), Offset(x - 2.0, y + p.length), paint);
      }
    } else if (particleType == ParticleType.fog) {
      // Overlapping soft volumetric drifting fog clouds using fast radial gradients
      paint.style = PaintingStyle.fill;
      for (final p in particles) {
        double scale = p.depth * 0.4 + 0.8; // 80% to 120% of base radius
        double radius = (size.width * 0.4) * scale;
        
        // Horizontal drift speed
        double floatSpeed = 0.3 + p.depth * 0.3;
        double driftX = ((p.baseX + progress * floatSpeed) % 1.0) * (size.width + radius * 2.0) - radius;
        double driftY = p.baseY * size.height;
        
        final rect = Rect.fromCircle(center: Offset(driftX, driftY), radius: radius);
        final gradient = RadialGradient(
          colors: [
            color.withOpacity(0.045),
            color.withOpacity(0.015),
            Colors.transparent,
          ],
        );
        paint.shader = gradient.createShader(rect);
        canvas.drawCircle(Offset(driftX, driftY), radius, paint);
      }
    } else if (particleType == ParticleType.stars || particleType == ParticleType.neon) {
      bool isNeon = particleType == ParticleType.neon;
      
      for (final p in particles) {
        double x = p.baseX * size.width;
        double y;
        
        if (isNeon) {
          // Neon drifts slowly upwards
          double floatSpeed = 0.08 + p.depth * 0.12;
          y = ((p.baseY - progress * floatSpeed) % 1.0) * size.height;
          // Organic horizontal sway
          double swayWidth = 10.0 + p.depth * 15.0;
          x += sin((progress * pi * 2.0 * p.swaySpeed) + p.randomOffset) * swayWidth;
        } else {
          // Stars twinkle in a fixed coordinate
          y = p.baseY * size.height;
        }
        
        // Soft twinkle frequency
        double twinkle = sin((progress * pi * 2.0 * p.twinkleSpeed) + p.randomOffset).abs();
        double radius = isNeon ? (2.0 + p.depth * 4.0) : (0.8 + p.depth * 1.5);
        
        if (isNeon) {
          // Outer glow shader for neon particles
          final outerPaint = Paint()
            ..color = color.withOpacity((0.08 + p.depth * 0.16) * twinkle)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
          canvas.drawCircle(Offset(x, y), radius * 2.2, outerPaint);
          
          // Glowing core
          paint.color = Colors.white.withOpacity((0.3 + p.depth * 0.5) * twinkle);
          canvas.drawCircle(Offset(x, y), radius, paint);
        } else {
          // Elegant starry sky circles
          paint.color = color.withOpacity((0.15 + p.depth * 0.65) * twinkle);
          canvas.drawCircle(Offset(x, y), radius, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CinematicParticlePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.particleType != particleType ||
      oldDelegate.color != color ||
      oldDelegate.particles != particles;
}
