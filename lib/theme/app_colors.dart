import 'package:flutter/cupertino.dart';

/// App-wide iOS system palette.
/// အရင်က home_screen.dart ထဲမှာပဲ ရှိတဲ့ အရောင်တွေကို screen တွေအားလုံး
/// မျှသုံးနိုင်အောင် ဒီနေရာကို ရွှေ့ထားတယ်။
class AppColors {
  AppColors._();

  static const Color green = Color(0xFF34C759);
  static const Color blue = Color(0xFF007AFF);
  static const Color orange = Color(0xFFFF9500);
  static const Color red = Color(0xFFFF3B30);
  static const Color teal = Color(0xFF5AC8FA);
  static const Color purple = Color(0xFFAF52DE);

  static const Color label = Color(0xFF1C1C1E);
  static const Color secondaryLabel = Color(0xFF8E8E93);
  static const Color background = Color(0xFFF2F2F7);
  static const Color card = CupertinoColors.white;
  static const Color separator = CupertinoColors.systemGrey5;
  static const Color fill = CupertinoColors.systemGrey6;
}
