import 'package:flutter/material.dart';

/// Semantic color definitions for light and dark themes.
///
/// Usage:
///   AppColors.of(context).background
///   AppColors.of(context).primary
class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color surface;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color primary;
  final Color primaryLight;
  final Color border;
  final Color borderLight;
  final Color navActiveBg;
  final Color iconMuted;
  final Color shadow;
  final Color divider;
  final Color inputBg;
  final Color inputBorder;
  final Color chipBg;
  final Color danger;
  final Color dangerLight;

  const AppColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.primaryLight,
    required this.border,
    required this.borderLight,
    required this.navActiveBg,
    required this.iconMuted,
    required this.shadow,
    required this.divider,
    required this.inputBg,
    required this.inputBorder,
    required this.chipBg,
    required this.danger,
    required this.dangerLight,
  });

  // ──────────────────── Light Theme ────────────────────
  static const light = AppColors(
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1E293B),
    textSecondary: Color(0xFF94A3B8),
    textTertiary: Color(0xFF64748B),
    primary: Color(0xFF6366F1),
    primaryLight: Color(0xFFEEF2FF),
    border: Color(0xFFE2E8F0),
    borderLight: Color(0xFFF1F5F9),
    navActiveBg: Color(0xFFEEF2FF),
    iconMuted: Color(0xFF94A3B8),
    shadow: Color(0x0A000000),
    divider: Color(0xFFF1F5F9),
    inputBg: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFCBD5E1),
    chipBg: Color(0xFFEEF2FF),
    danger: Color(0xFFEF4444),
    dangerLight: Color(0xFFFEF2F2),
  );

  // ──────────────────── Dark Theme ────────────────────
  static const dark = AppColors(
    background: Color(0xFF0F172A),
    surface: Color(0xFF1E293B),
    card: Color(0xFF1E293B),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    textTertiary: Color(0xFF64748B),
    primary: Color(0xFF818CF8),
    primaryLight: Color(0xFF1E1B4B),
    border: Color(0xFF334155),
    borderLight: Color(0xFF1E293B),
    navActiveBg: Color(0xFF1E1B4B),
    iconMuted: Color(0xFF64748B),
    shadow: Color(0x1A000000),
    divider: Color(0xFF1E293B),
    inputBg: Color(0xFF1E293B),
    inputBorder: Color(0xFF334155),
    chipBg: Color(0xFF1E1B4B),
    danger: Color(0xFFF87171),
    dangerLight: Color(0xFF2D1B1B),
  );

  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>()!;
  }

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? primary,
    Color? primaryLight,
    Color? border,
    Color? borderLight,
    Color? navActiveBg,
    Color? iconMuted,
    Color? shadow,
    Color? divider,
    Color? inputBg,
    Color? inputBorder,
    Color? chipBg,
    Color? danger,
    Color? dangerLight,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      border: border ?? this.border,
      borderLight: borderLight ?? this.borderLight,
      navActiveBg: navActiveBg ?? this.navActiveBg,
      iconMuted: iconMuted ?? this.iconMuted,
      shadow: shadow ?? this.shadow,
      divider: divider ?? this.divider,
      inputBg: inputBg ?? this.inputBg,
      inputBorder: inputBorder ?? this.inputBorder,
      chipBg: chipBg ?? this.chipBg,
      danger: danger ?? this.danger,
      dangerLight: dangerLight ?? this.dangerLight,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderLight: Color.lerp(borderLight, other.borderLight, t)!,
      navActiveBg: Color.lerp(navActiveBg, other.navActiveBg, t)!,
      iconMuted: Color.lerp(iconMuted, other.iconMuted, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      inputBg: Color.lerp(inputBg, other.inputBg, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      chipBg: Color.lerp(chipBg, other.chipBg, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerLight: Color.lerp(dangerLight, other.dangerLight, t)!,
    );
  }
}
