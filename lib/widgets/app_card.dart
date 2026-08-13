import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// App တစ်ခုလုံးရဲ့ card အခြေခံ။
///
/// အရင်က screen တစ်ခုချင်းစီမှာ `Container(border: ..., radius: 14)` ကို
/// အသီးသီး ရေးထားတာမို့ အနားသတ်/အကွေး/အရိပ် တွေ မတူညီဘူး။ ဒီမှာ
/// မျဉ်းကြောင်းအစား အရိပ်နူးနူး သုံးထားတယ် — ပိုသန့်ပြီး ခေတ်မီတယ်။
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.children, this.padding = EdgeInsets.zero});

  /// Padding မပါဘဲ row တွေ တန်းစီဖို့ (separator တွေ အနားထိ ရောက်အောင်)။
  const AppCard.rows({super.key, required this.children}) : padding = EdgeInsets.zero;

  /// အထဲမှာ စာသား/widget တွေ ထည့်ဖို့ — ဘေးပတ်လည် padding ပါတယ်။
  AppCard.padded({super.key, required this.children, double gap = AppSpacing.lg}) : padding = EdgeInsets.all(gap);

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: AppRadius.card, boxShadow: AppShadow.card),
      child: ClipRRect(
        // Row တွေက card ရဲ့ အကွေးအတိုင်း ဖြတ်ခံရအောင် — ထောင့်စွန်းက ကျော်မထွက်ဘူး။
        borderRadius: AppRadius.card,
        child: Padding(
          padding: padding,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}

/// Card အတွင်းက အတန်းများကြား မျဉ်းပါးလေး (Cupertino မှာ Divider မရှိလို့)။
class AppSeparator extends StatelessWidget {
  const AppSeparator({super.key, this.indent = 66});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Container(height: 0.7, margin: EdgeInsets.only(left: indent), color: AppColors.separator);
  }
}

/// အပိုင်းခေါင်းစဉ် — icon လေးနဲ့ စာသား။
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.icon, required this.title, required this.color, this.trailing});

  final IconData icon;
  final String title;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(title, overflow: TextOverflow.ellipsis, style: AppText.section)),
          ?trailing,
        ],
      ),
    );
  }
}
