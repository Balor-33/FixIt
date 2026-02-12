import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  const AppCard({super.key, required this.child, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseShadow = [
      BoxShadow(
        color: Colors.black.withOpacity(0.18),
        blurRadius: 28,
        offset: const Offset(0, 16),
      ),
      BoxShadow(
        color: Colors.white.withOpacity(0.04),
        blurRadius: 0,
        offset: const Offset(0, 0),
      ),
    ];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: baseShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              child: Padding(
                padding: padding ?? const EdgeInsets.all(AppSpacing.md),
                child: SizedBox(width: double.infinity, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
