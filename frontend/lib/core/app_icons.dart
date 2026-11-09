import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Centralized icon definitions using Phosphor Icons (https://phosphoricons.com).
///
/// Since the `@staticIconProvider` annotation may not be processed in this
/// build environment, we use PhosphorIconsFill (filled variant) directly
/// which works as standard IconData values.
class AppIcons {
  // ──────────────────── Admin Dashboard ────────────────────
  static const dashboardFill = PhosphorIconsFill.layout;
  static const usersFill = PhosphorIconsFill.users;
  static const usersThree = PhosphorIconsFill.usersThree;
  static const clipboardTextFill = PhosphorIconsFill.clipboardText;
  static const student = PhosphorIconsFill.student;
  static const firstAidFill = PhosphorIconsFill.firstAid;
  static const smileyFill = PhosphorIconsFill.smiley;
  static const warningFill = PhosphorIconsFill.warning;
  static const shieldCheckFill = PhosphorIconsFill.shieldCheck;
  static const profileFill = PhosphorIconsFill.userCircle;
  static const signOutIcon = PhosphorIconsFill.signOut;
  static const usersIcon = PhosphorIconsFill.users;
}
