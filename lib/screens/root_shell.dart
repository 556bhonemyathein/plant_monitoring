import 'package:flutter/cupertino.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_nav_bar.dart';
import 'ai_scan_screen.dart';
import 'camera_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Tab အားလုံးအတွက် scroll အောက်ခြေမှာ ချန်ရမယ့် နေရာ
/// (floating nav bar အောက်မှာ content တွေ မပျောက်အောင်)။
const double kNavBarClearance = 96;

/// လက်ရှိဖွင့်ထားတဲ့ tab ကို descendant တွေ သိနိုင်အောင် အောက်ကို ပို့ပေးတယ်။
///
/// IndexedStack သုံးထားတာမို့ tab အားလုံး တစ်ပြိုင်တည်း "အသက်ရှင်" နေတယ်။
/// ESP32-CAM က stream client တစ်ခုတည်းသာ လက်ခံတာမို့ Home နဲ့ Live နှစ်ခုလုံးက
/// တစ်ပြိုင်တည်း ချိတ်ရင် နောက်တစ်ခုက ပုံမရဘူး — ဒါကြောင့် မမြင်ရတဲ့ tab ရဲ့
/// stream ကို ဖြုတ်ထားဖို့ ဒီ index ကို သုံးတယ်။
class ActiveTab extends InheritedWidget {
  const ActiveTab({super.key, required this.index, required super.child});

  final int index;

  static const int home = 0;
  static const int live = 1;

  /// [tab] က လက်ရှိမြင်နေရတဲ့ tab ဟုတ်မဟုတ်။
  static bool isActive(BuildContext context, int tab) {
    final scope = context.dependOnInheritedWidgetOfExactType<ActiveTab>();
    return scope == null || scope.index == tab;
  }

  @override
  bool updateShouldNotify(ActiveTab oldWidget) => oldWidget.index != index;
}

/// App ရဲ့ အဓိက shell — bottom navigation bar နဲ့ tab ၄ ခုကို ကိုင်တွယ်တယ်။
///
/// IndexedStack သုံးထားတာမို့ tab ပြောင်းလည်း screen တစ်ခုချင်းရဲ့ state
/// (camera stream, AI ရလဒ်, scroll position) မပျက်ဘဲ ဆက်ရှိနေတယ်။
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  List<NavDestination> _destinations(AppStrings s) => [
    NavDestination(icon: CupertinoIcons.house, activeIcon: CupertinoIcons.house_fill, label: s.navHome, color: AppColors.green),
    NavDestination(icon: CupertinoIcons.videocam, activeIcon: CupertinoIcons.videocam_fill, label: s.navLive, color: AppColors.blue),
    NavDestination(icon: CupertinoIcons.sparkles, activeIcon: CupertinoIcons.sparkles, label: s.navAiScan, color: AppColors.purple),
    NavDestination(icon: CupertinoIcons.settings, activeIcon: CupertinoIcons.settings_solid, label: s.navSettings, color: AppColors.secondaryLabel),
  ];

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.of(context);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Stack(
        children: [
          Positioned.fill(
            child: ActiveTab(
              index: _index,
              child: IndexedStack(
                index: _index,
                children: const [HomeScreen(), CameraScreen(), AiScanScreen(), SettingsScreen()],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GlassNavBar(
              destinations: _destinations(s),
              currentIndex: _index,
              onSelected: (i) => setState(() => _index = i),
            ),
          ),
        ],
      ),
    );
  }
}
