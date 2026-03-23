import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.borderRadius = 16.0,
    this.color,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A3E2A1E), // Soft dark shadow
            offset: Offset(4, 4),
            blurRadius: 10,
          ),
          BoxShadow(
            color: Colors.white, // Light highlight
            offset: Offset(-4, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }
}
