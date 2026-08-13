import 'package:flutter/cupertino.dart';

import 'app_colors.dart';

/// App တစ်ခုလုံးအတွက် အကွာအဝေး (spacing) စံနှုန်း။
///
/// အရင်က screen တစ်ခုချင်းစီမှာ 8/10/12/14/16 စသဖြင့် ကွဲကွဲပြားပြား
/// ရေးထားတာမို့ တစ်ပုံစံတည်း မဖြစ်ဘူး — ဒီ scale ကိုပဲ သုံးရင် စာမျက်နှာတိုင်း
/// ညီညာသွားတယ်။
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// အနားသတ် အကွေး (corner radius)။ ခေတ်မီတဲ့ iOS app တွေက အကွေး ပိုကြီးတယ်။
abstract final class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double pill = 999;

  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get tile => BorderRadius.circular(md);
  static BorderRadius get chip => BorderRadius.circular(sm);
}

/// အရိပ်များ။ မျဉ်းကြောင်း (border) အစား အရိပ်နူးနူးလေး သုံးတာက
/// ပိုသန့်ပြီး ခေတ်မီတယ် — card တွေက စာမျက်နှာပေါ်မှာ "မျောနေသလို" ဖြစ်တယ်။
abstract final class AppShadow {
  /// ပုံမှန် card အတွက် — အလွန်နူးညံ့တဲ့ အရိပ် နှစ်ထပ်။
  static List<BoxShadow> get card => [
    BoxShadow(color: const Color(0xFF0B1F33).withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 6)),
    BoxShadow(color: const Color(0xFF0B1F33).withValues(alpha: 0.03), blurRadius: 3, offset: const Offset(0, 1)),
  ];

  /// အရောင်ရှိတဲ့ ခလုတ်တွေအတွက် — ခလုတ်ရဲ့ အရောင်နဲ့ လိုက်ဖက်တဲ့ အလင်းရိပ်။
  static List<BoxShadow> glow(Color color) => [
    BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 16, offset: const Offset(0, 8)),
  ];
}

/// စာလုံး စံနှုန်း — အရွယ်အစား/အလေးချိန်ကို ဒီနေရာကနေပဲ ချိန်ရအောင်။
abstract final class AppText {
  /// စာမျက်နှာ ခေါင်းစဉ်ကြီး။
  static const TextStyle title = TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.label, letterSpacing: -0.5);

  /// အပိုင်း (section) ခေါင်းစဉ်။
  static const TextStyle section = TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.label, letterSpacing: -0.2);

  /// List row ရဲ့ ခေါင်းစဉ်။
  static const TextStyle rowTitle = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: AppColors.label);

  /// Row ရဲ့ အောက်က ရှင်းလင်းချက်။
  static const TextStyle rowSubtitle = TextStyle(fontSize: 12.5, color: AppColors.secondaryLabel, height: 1.35);

  /// ဂဏန်းအကြီး (sensor တန်ဖိုး)။
  static const TextStyle metric = TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.label, letterSpacing: -1);

  /// အသေးဆုံး caption/label။
  static const TextStyle caption = TextStyle(fontSize: 11.5, color: AppColors.secondaryLabel, height: 1.25);
}

/// အရောင်ခြယ်ထားတဲ့ icon ကွက် — row/tile တိုင်းမှာ တစ်ပုံစံတည်း ဖြစ်အောင်။
class IconChip extends StatelessWidget {
  const IconChip({super.key, required this.icon, required this.color, this.size = 38});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // အပေါ်က ပိုတောက်၊ အောက်က ပိုဖျော့ — အပြားလိုက်မဟုတ်ဘဲ အနည်းငယ် အထူရှိသလို ဖြစ်စေတယ်။
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.10)],
        ),
        borderRadius: BorderRadius.circular(size * 0.30),
      ),
      child: Center(child: Icon(icon, color: color, size: size * 0.50)),
    );
  }
}
