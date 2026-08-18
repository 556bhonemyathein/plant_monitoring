import 'package:flutter/cupertino.dart';

import '../l10n/app_strings.dart';
import '../models/resource_item.dart';
import '../services/resource_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';

/// ပိုးမွှား/ဆေး၊ မြေဩဇာ၊ စပါးမျိုး အချက်အလက်တွေကို ရှာဖွေကြည့်ရှုတဲ့ အပိုင်း။
///
/// အချက်အလက်တွေက Word စာရွက်စာတမ်းကနေ ထုတ်ထားတဲ့ JSON asset ထဲမှာ ရှိတယ်
/// (`tool/extract_resources.py` ကြည့်ပါ) — offline မှာလည်း အလုပ်လုပ်တယ်။
class ResourceBrowser extends StatefulWidget {
  const ResourceBrowser({super.key});

  @override
  State<ResourceBrowser> createState() => _ResourceBrowserState();
}

class _ResourceBrowserState extends State<ResourceBrowser> {
  final TextEditingController _search = TextEditingController();
  late final Future<ResourceLibrary> _library = ResourceService.instance.load();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static (IconData, Color) _style(ResourceKind kind) => switch (kind) {
    ResourceKind.pest => (CupertinoIcons.ant_fill, AppColors.red),
    ResourceKind.fertiliser => (CupertinoIcons.cube_box_fill, AppColors.green),
    ResourceKind.guideline => (CupertinoIcons.checkmark_seal_fill, AppColors.blue),
    ResourceKind.growthStage => (CupertinoIcons.calendar_badge_plus, AppColors.teal),
  };

  /// Item တစ်ခုချင်းစီအတွက် icon/အရောင် — အမျိုးအစားတစ်ခုလုံး တစ်ပုံစံတည်း
  /// မဟုတ်ဘဲ အကြောင်းအရာနဲ့ ကိုက်တဲ့ သင်္ကေတ ပြတယ် (ဥပမာ ရေသွင်းရေထုတ် ဆိုရင်
  /// ရေစက်၊ ပေါင်းသတ်ဆေး ဆိုရင် ဆေးဖျန်းပုံး)။ စာသားမဖတ်ရဘဲ ဘာအကြောင်းလဲ
  /// ချက်ချင်း သိအောင်ပါ။
  static (IconData, Color) _itemStyle(ResourceItem item) {
    if (item.kind == ResourceKind.guideline) {
      if (item.title.contains('ရေ')) return (CupertinoIcons.drop_fill, AppColors.blue);
      if (item.title.contains('ဆေး')) return (CupertinoIcons.drop_triangle_fill, AppColors.orange);
      if (item.title.contains('မြေ')) return (CupertinoIcons.square_stack_3d_down_right_fill, AppColors.teal);
    }
    return _style(item.kind);
  }

  String _kindLabel(AppStrings s, ResourceKind kind) => switch (kind) {
    ResourceKind.pest => s.resourcePests,
    ResourceKind.fertiliser => s.resourceFertilisers,
    ResourceKind.guideline => s.resourceGuidelines,
    ResourceKind.growthStage => s.resourceGrowthStages,
  };

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.of(context);

    return FutureBuilder<ResourceLibrary>(
      future: _library,
      builder: (context, snapshot) {
        final library = snapshot.data;
        if (library == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        if (library.items.isEmpty) return const SizedBox.shrink();

        final results = library.search(_query);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(icon: CupertinoIcons.book, title: s.resourceSection, color: AppColors.teal),
            CupertinoSearchTextField(
              controller: _search,
              placeholder: s.resourceSearchHint,
              backgroundColor: AppColors.fill,
              borderRadius: AppRadius.tile,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              // အရောင်တွေကို အတိအကျ ထည့်ပေးထားတယ် — theme ပြောင်းလည်း
              // ရိုက်ထည့်တဲ့ စာက အမြဲ ဖတ်လို့ရနေအောင်။
              style: const TextStyle(fontSize: 15.5, color: AppColors.label, height: 1.4),
              placeholderStyle: const TextStyle(fontSize: 15, color: AppColors.secondaryLabel, height: 1.4),
              itemColor: AppColors.secondaryLabel,
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ရှာနေချိန်မှာ အမျိုးအစားအလိုက် မခွဲတော့ဘဲ တွေ့သမျှကို စာရင်းလိုက် ပြတယ်။
            if (_query.trim().isNotEmpty)
              _results(s, results)
            else
              for (final kind in ResourceKind.values) ...[
                _kindHeader(s, kind, library.of(kind).length),
                _row(library.of(kind)),
                const SizedBox(height: AppSpacing.lg),
                // မြေဩဇာ အပိုင်း အောက်မှာ ကျွေးရမယ့် အချိန်ဇယားကို တွဲပြတယ်။
                if (kind == ResourceKind.fertiliser && library.schedule.isNotEmpty) ...[
                  _schedule(s, library.schedule),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
          ],
        );
      },
    );
  }

  Widget _kindHeader(AppStrings s, ResourceKind kind, int count) {
    final (icon, color) = _style(kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(_kindLabel(s, kind), style: AppText.rowTitle),
          const SizedBox(width: 6),
          Text('$count', style: AppText.caption),
        ],
      ),
    );
  }

  /// အလျားလိုက် ပွတ်ဆွဲကြည့်ရတဲ့ card အတန်း။
  Widget _row(List<ResourceItem> items) {
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) => _card(items[i]),
      ),
    );
  }

  Widget _card(ResourceItem item) {
    final (icon, color) = _itemStyle(item);
    return GestureDetector(
      onTap: () => _openDetail(item),
      child: Container(
        width: 148,
        decoration: BoxDecoration(color: AppColors.card, borderRadius: AppRadius.card, boxShadow: AppShadow.card),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 88,
              child: item.images.isEmpty
                  ? ColoredBox(color: color.withValues(alpha: 0.10), child: Icon(icon, size: 30, color: color))
                  : Image.asset(
                      item.images.first,
                      fit: BoxFit.cover,
                      // ပုံ ဖတ်လို့မရရင် card တစ်ခုလုံး ပျက်မသွားစေဖို့ icon နဲ့ အစားထိုးတယ်။
                      errorBuilder: (_, _, _) => ColoredBox(color: color.withValues(alpha: 0.10), child: Icon(icon, size: 30, color: color)),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.label, height: 1.25),
                    ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// တစ်ဧကအတွက် မြေဩဇာ ကျွေးရမယ့် အချိန်ဇယား။
  ///
  /// ဇယားကို အတန်းလိုက် ဖြန့်ပြတာက ဖုန်းအကျယ်နဲ့ ပိုကိုက်တယ် — column ၆ ခုကို
  /// အတင်းညှစ်ထည့်ရင် မြန်မာစာက ကျဉ်းလွန်းပြီး ဖတ်မရဘူး။
  Widget _schedule(AppStrings s, List<FertiliserStage> schedule) {
    return AppCard.rows(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(
            children: [
              const Icon(CupertinoIcons.calendar, size: 15, color: AppColors.green),
              const SizedBox(width: 6),
              Expanded(child: Text(s.resourceSchedule, style: AppText.rowTitle)),
            ],
          ),
        ),
        for (final stage in schedule) ...[
          const AppSeparator(indent: 14),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stage.stage, style: AppText.rowTitle),
                if (stage.age.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(stage.age, style: AppText.caption),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 6,
                  children: [
                    _amount(s.fertUrea, stage.urea, AppColors.blue),
                    _amount(s.fertPhosphate, stage.phosphate, AppColors.purple),
                    _amount(s.fertPotash, stage.potash, AppColors.orange),
                  ],
                ),
                if (stage.purpose.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(stage.purpose, style: AppText.rowSubtitle),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// "ပုလဲ · အိတ်ဝက်" ပုံစံ chip — ကျွေးစရာ မရှိရင် (`-`) လုံးဝ မပြဘူး။
  Widget _amount(String label, String value, Color color) {
    final has = value.isNotEmpty && value != '-';
    if (!has) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(fontSize: 12, color: AppColors.label),
          ),
        ],
      ),
    );
  }

  Widget _results(AppStrings s, List<ResourceItem> results) {
    if (results.isEmpty) {
      return AppCard.padded(
        children: [Text(s.resourceNoResults, style: AppText.rowSubtitle)],
      );
    }
    return AppCard.rows(
      children: [
        for (var i = 0; i < results.length; i++) ...[
          if (i > 0) const AppSeparator(),
          _resultRow(results[i]),
        ],
      ],
    );
  }

  Widget _resultRow(ResourceItem item) {
    final (icon, color) = _itemStyle(item);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: BorderRadius.zero,
      minimumSize: Size.zero,
      onPressed: () => _openDetail(item),
      child: Row(
        children: [
          IconChip(icon: icon, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: AppText.rowTitle),
                const SizedBox(height: 2),
                Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.rowSubtitle),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(CupertinoIcons.chevron_right, size: 15, color: AppColors.secondaryLabel),
        ],
      ),
    );
  }

  void _openDetail(ResourceItem item) {
    showCupertinoModalPopup<void>(context: context, builder: (context) => _ResourceDetailSheet(item: item));
  }
}

/// အသေးစိတ် စာမျက်နှာ — အောက်ကနေ တက်လာတဲ့ sheet။
class _ResourceDetailSheet extends StatelessWidget {
  const _ResourceDetailSheet({required this.item});

  final ResourceItem item;

  /// ဆေးဘူး ဓာတ်ပုံ — တောင်သူက ဆိုင်မှာ မြင်ဖူးတဲ့ ထုပ်ပိုးမှုကို ချက်ချင်း
  /// မှတ်မိအောင် နံပါတ်အစား ဓာတ်ပုံ ပြတယ်။ ပုံမရှိရင်တော့ နံပါတ်နဲ့ အစားထိုးတယ်။
  Widget _productPhoto(Treatment treatment, int index) {
    const double size = 52;

    Widget fallback() => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: 0.12), borderRadius: AppRadius.chip),
      child: Center(
        child: Text(
          '${index + 1}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.blue),
        ),
      ),
    );

    if (treatment.images.isEmpty) return fallback();
    return ClipRRect(
      borderRadius: AppRadius.chip,
      child: Container(
        width: size,
        height: size,
        color: AppColors.fill,
        // ဆေးဘူးပုံတွေက အချိုးအစား မတူတာမို့ contain နဲ့ ပြမှ မဖြတ်တောက်ဘဲ အပြည့်မြင်ရတယ်။
        child: Image.asset(treatment.images.first, fit: BoxFit.contain, errorBuilder: (_, _, _) => fallback()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.of(context);
    final media = MediaQuery.of(context);

    return Container(
      height: media.size.height * 0.82,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        children: [
          // ဆွဲချလို့ရကြောင်း ပြတဲ့ လက်ကိုင်တံ။
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: AppColors.separator, borderRadius: BorderRadius.circular(3)),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, media.padding.bottom + AppSpacing.xl),
              children: [
                Text(item.title, style: AppText.title),
                const SizedBox(height: AppSpacing.md),
                if (item.images.isNotEmpty) ...[
                  SizedBox(
                    height: 180,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: item.images.length,
                      separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
                      itemBuilder: (context, i) => ClipRRect(
                        borderRadius: AppRadius.card,
                        child: Image.asset(
                          item.images[i],
                          width: 220,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (item.body.isNotEmpty)
                  AppCard.padded(
                    children: [
                      Text(
                        item.kind == ResourceKind.pest ? s.resourceSymptomLabel : s.resourceDetailLabel,
                        style: AppText.caption,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(item.body, style: const TextStyle(fontSize: 14.5, color: AppColors.label, height: 1.5)),
                    ],
                  ),
                // လက်နဲ့ ဖြည့်ထားတဲ့ အပိုင်းများ — အကျိုးကျေးဇူး / ကျွေးရမည့်အကြိမ် / နှုန်းထား။
                for (final section in item.sections) ...[
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(icon: CupertinoIcons.list_bullet, title: section.title, color: AppColors.green),
                  AppCard.rows(
                    children: [
                      for (var i = 0; i < section.points.length; i++) ...[
                        if (i > 0) const AppSeparator(indent: 14),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 5),
                                    child: Icon(CupertinoIcons.checkmark_circle_fill, size: 14, color: AppColors.green),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(child: Text(section.points[i].label, style: AppText.rowTitle)),
                                ],
                              ),
                              if (section.points[i].detail.isNotEmpty)
                                Padding(
                                  // စာကြောင်းက icon အောက်မှာ မဟုတ်ဘဲ ခေါင်းစဉ်နဲ့ တစ်တန်းတည်း ကျအောင်။
                                  padding: const EdgeInsets.only(left: 22, top: 4),
                                  child: Text(section.points[i].detail, style: AppText.rowSubtitle),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                if (item.treatments.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(icon: CupertinoIcons.drop_triangle_fill, title: s.resourceTreatments, color: AppColors.blue),
                  AppCard.rows(
                    children: [
                      for (var i = 0; i < item.treatments.length; i++) ...[
                        if (i > 0) const AppSeparator(indent: 14),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _productPhoto(item.treatments[i], i),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.treatments[i].name, style: AppText.rowTitle),
                                        if (item.treatments[i].usage.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(item.treatments[i].usage, style: AppText.rowSubtitle),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  height: 50,
                  child: CupertinoButton(
                    color: AppColors.green,
                    borderRadius: AppRadius.tile,
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      s.close,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CupertinoColors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
