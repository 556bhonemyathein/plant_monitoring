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
            child: IndexedStack(
              index: _index,
              children: const [HomeScreen(), CameraScreen(), AiScanScreen(), SettingsScreen()],
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
