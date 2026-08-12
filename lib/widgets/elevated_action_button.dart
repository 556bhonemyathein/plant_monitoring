import 'package:flutter/cupertino.dart';

/// အသေးစိတ် စာသားပါတဲ့ "မြင့်တက်နေတဲ့" (elevated) ခလုတ်။
///
/// ပုံမှန် card တွေက အပြားလိုက် (flat) ဖြစ်ပေမယ့် ဒီခလုတ်ကတော့ gradient နဲ့
/// အရိပ် နှစ်ထပ် ထည့်ထားတာမို့ စာမျက်နှာပေါ်မှာ ထင်ရှားပြီး "အဓိက လုပ်ဆောင်ချက်"
/// ဆိုတာ မြင်ရုံနဲ့ သိတယ်။ နှိပ်လိုက်ရင် အနည်းငယ် သေးသွားပြီး အရိပ်လည်း
/// လျော့သွားတာမို့ တကယ် ဖိလိုက်သလို ခံစားရတယ် (iOS ပုံစံ)။
///
/// [title] — ခလုတ်ရဲ့ အဓိက စာသား
/// [subtitle] — ဘာလုပ်ပေးမလဲ ဆိုတာ တစ်ကြောင်း
/// [detail] — ထပ်ဆောင်း ရှင်းလင်းချက် (မလိုရင် ချန်ထားလို့ရတယ်)
/// [actionLabel] — ညာဘက် pill ထဲက စာသား (မပေးရင် chevron ပဲ ပြတယ်)
class ElevatedActionButton extends StatefulWidget {
  const ElevatedActionButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onPressed,
    this.detail,
    this.actionLabel,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? detail;
  final String? actionLabel;
  final Color color;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  State<ElevatedActionButton> createState() => _ElevatedActionButtonState();
}

class _ElevatedActionButtonState extends State<ElevatedActionButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _setPressed(bool value) {
    if (!_enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    // မနှိပ်ထားချိန်မှာ အရိပ်က ပိုကျယ် — နှိပ်လိုက်ရင် ကပ်သွားသလို ကျဉ်းသွားတယ်။
    final elevation = _pressed ? 0.45 : 1.0;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _enabled
                  ? [color, Color.lerp(color, const Color(0xFF000000), 0.22)!]
                  : [color.withValues(alpha: 0.45), color.withValues(alpha: 0.45)],
            ),
            boxShadow: _enabled
                ? [
                    // ၁) အရောင်နဲ့ လိုက်ဖက်တဲ့ အရိပ် — "အလင်းရောင် ထွက်နေသလို" ခံစားချက်။
                    BoxShadow(
                      color: color.withValues(alpha: 0.34 * elevation),
                      blurRadius: 22 * elevation,
                      offset: Offset(0, 10 * elevation),
                    ),
                    // ၂) မှိန်တဲ့ အနက်ရောင် အရိပ် — အနားသတ်ကို ကွက်ကွက်ကွင်းကွင်း ဖြစ်စေတယ်။
                    BoxShadow(
                      color: const Color(0xFF000000).withValues(alpha: 0.10 * elevation),
                      blurRadius: 6 * elevation,
                      offset: Offset(0, 2 * elevation),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: CupertinoColors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: CupertinoColors.white.withValues(alpha: 0.25)),
                ),
                child: widget.loading
                    ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                    : Icon(widget.icon, size: 22, color: CupertinoColors.white),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: CupertinoColors.white, letterSpacing: 0.1),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: CupertinoColors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    if (widget.detail != null) ...[
                      const SizedBox(height: 8),
                      // အသေးစိတ် စာသားက ပိုမှိန်တာမို့ ခေါင်းစဉ်ကို မလုပ်ကြံဘူး။
                      Text(
                        widget.detail!,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: CupertinoColors.white.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                    if (widget.actionLabel != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: CupertinoColors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.actionLabel!,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: CupertinoColors.white),
                            ),
                            const SizedBox(width: 5),
                            const Icon(CupertinoIcons.arrow_up_right, size: 12, color: CupertinoColors.white),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Icon(CupertinoIcons.chevron_right, size: 16, color: CupertinoColors.white.withValues(alpha: 0.75)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
