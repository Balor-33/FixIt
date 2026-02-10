import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final Widget? header;
  final double headerHeight;
  final bool useSurfaceBody;

  const AppScaffold({
    super.key,
    required this.body,
    this.header,
    this.headerHeight = 220,
    this.useSurfaceBody = true,
  });

  EdgeInsets _responsivePadding(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    if (width >= 900) {
      return const EdgeInsets.symmetric(horizontal: 40);
    }
    if (width >= 600) {
      return const EdgeInsets.symmetric(horizontal: 32);
    }
    return const EdgeInsets.symmetric(horizontal: 20);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = _responsivePadding(constraints);
        return Scaffold(
          body: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0F172A),
                      Color(0xFF111827),
                      Color(0xFF1E293B),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -120,
                right: -80,
                child: _GlowOrb(color: AppTheme.electric.withOpacity(0.6)),
              ),
              Positioned(
                top: 120,
                left: -90,
                child: _GlowOrb(color: AppTheme.violet.withOpacity(0.5)),
              ),
              SafeArea(
                child: Column(
                  children: [
                  if (header != null)
                    Container(
                      height: headerHeight,
                      width: double.infinity,
                      padding: horizontalPadding,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(AppRadii.xl),
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: header,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: header != null
                            ? const BorderRadius.vertical(
                                top: Radius.circular(AppRadii.xl),
                              )
                            : BorderRadius.zero,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Container(
                            width: double.infinity,
                            padding: horizontalPadding.copyWith(
                              top: AppSpacing.xl,
                              bottom: AppSpacing.xl,
                            ),
                            decoration: BoxDecoration(
                              color: useSurfaceBody
                                  ? colorScheme.surface.withOpacity(0.92)
                                  : Colors.transparent,
                              borderRadius: header != null
                                  ? const BorderRadius.vertical(
                                      top: Radius.circular(AppRadii.xl),
                                    )
                                  : null,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.08),
                              ),
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 760,
                                ),
                                child: body,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;

  const _GlowOrb({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }
}
