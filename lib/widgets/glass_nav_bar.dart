import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

class NavDestination {
  const NavDestination({required this.icon, required this.activeIcon, required this.label, required this.color});

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;
}

/// Floating frosted-glass bottom navigation bar.
///
/// Item တစ်ခုကို ရွေးလိုက်ရင် အဲ့ item က pill အဖြစ် ချဲ့ထွက်လာပြီး label ပေါ်လာတယ်။
/// မရွေးထားတဲ့ item တွေက icon သီးသန့်ပဲ ပြတယ် — screen အလျားလိုက် နေရာ သက်သာဖို့ပါ။
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({super.key, required this.destinations, required this.currentIndex, required this.onSelected});

  static const double barHeight = 62;

  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: bottomInset > 0 ? bottomInset - 4 : 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: barHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: CupertinoColors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: CupertinoColors.white.withValues(alpha: 0.6)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.label.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < destinations.length; i++) _NavItem(destination: destinations[i], selected: i == currentIndex, onTap: () => _select(i)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _select(int index) {
    if (index == currentIndex) return;
    HapticFeedback.selectionClick();
    onSelected(index);
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.destination, required this.selected, required this.onTap});

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? destination.color : AppColors.secondaryLabel;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        height: 44,
        padding: EdgeInsets.symmetric(horizontal: selected ? 14 : 12),
        decoration: BoxDecoration(
          color: selected ? destination.color.withValues(alpha: 0.14) : const Color(0x00000000),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? destination.activeIcon : destination.icon, size: 22, color: color),
            // Label ကို selected ဖြစ်တဲ့အခါမှာပဲ animation နဲ့ ဖွင့်ပြတယ်။
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: Text(
                        destination.label,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
