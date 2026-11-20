import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../state/app_state.dart';

/// iOS Liquid Glass surface with Gaussian backdrop blur and specular rim lighting.
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blurSigma;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.padding,
    this.blurSigma = 24,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [Colors.white.withValues(alpha: 0.14), Colors.white.withValues(alpha: 0.05)]
                  : [Colors.white.withValues(alpha: 0.72), Colors.white.withValues(alpha: 0.42)],
            ),
            border: Border.all(
              width: 1.0,
              color: isDark ? Colors.white.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.85),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Renders the user's custom gender asset icon with a graceful fallback.
class UserGenderAvatar extends StatelessWidget {
  final UserGender gender;
  final double size;
  final bool isApple;

  const UserGenderAvatar({super.key, required this.gender, this.size = 44, required this.isApple});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        gender.assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            isApple ? CupertinoIcons.person_fill : Icons.person,
            size: size * 0.55,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
