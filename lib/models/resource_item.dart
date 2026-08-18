/// `assets/data/resources.json` ထဲက အချက်အလက်တွေရဲ့ model။
///
/// JSON ကို `tool/extract_resources.py` က Word စာရွက်စာတမ်း နှစ်ခုကနေ
/// ထုတ်ပေးတာမို့ ဒီဖိုင်ထဲမှာ စာသားတွေ လက်နဲ့ ရေးမထားပါ — စာရွက်စာတမ်း
/// ပြင်ရင် script ပြန်ဖွင့်ရုံနဲ့ app ထဲက အချက်အလက်တွေ အသစ်ဖြစ်သွားတယ်။
library;

/// အရင်းအမြစ် အမျိုးအစား — UI မှာ အရောင်/icon ခွဲဖို့နဲ့ ရှာဖွေမှု စစ်ထုတ်ဖို့။
enum ResourceKind { pest, fertiliser, guideline, growthStage }

/// ခေါင်းစဉ်တစ်ခုအောက်က အချက်တစ်ချက် ("အပင် ကြီးထွားစေရန် — ...")။
class DetailPoint {
  const DetailPoint({required this.label, required this.detail});

  final String label;
  final String detail;

  factory DetailPoint.fromJson(Map<String, dynamic> json) => DetailPoint(
    label: (json['label'] ?? '').toString().trim(),
    detail: (json['detail'] ?? '').toString().trim(),
  );
}

/// အသေးစိတ် စာမျက်နှာမှာ ပြမယ့် အပိုင်းတစ်ပိုင်း (ခေါင်းစဉ် + အချက်များ)။
///
/// ဒါတွေက Word စာရွက်စာတမ်းထဲမှာ မပါဘဲ လက်နဲ့ ဖြည့်ထားတဲ့ အချက်အလက်တွေ —
/// `assets/data/resource_details.json` ကြည့်ပါ။
class DetailSection {
  const DetailSection({required this.title, required this.points});

  final String title;
  final List<DetailPoint> points;

  factory DetailSection.fromJson(Map<String, dynamic> json) => DetailSection(
    title: (json['title'] ?? '').toString().trim(),
    points: [
      for (final p in (json['items'] as List? ?? const []))
        if (p is Map<String, dynamic>) DetailPoint.fromJson(p),
    ],
  );
}

/// ပိုးမွှား တစ်မျိုးအတွက် ကာကွယ်ဆေး တစ်လက်။
class Treatment {
  const Treatment({required this.name, required this.usage, required this.images});

  final String name;
  final String usage;
  final List<String> images;

  factory Treatment.fromJson(Map<String, dynamic> json) => Treatment(
    name: (json['name'] ?? '').toString().trim(),
    usage: (json['usage'] ?? '').toString().trim(),
    images: _strings(json['images']),
  );
}

/// ရှာဖွေလို့ရတဲ့ အရင်းအမြစ် တစ်ခု (ပိုးမွှား / မြေဩဇာ / လိုက်နာရမည့် နည်းလမ်း)။
class ResourceItem {
  const ResourceItem({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.images,
    this.treatments = const [],
    this.sections = const [],
  });

  final ResourceKind kind;
  final String title;

  /// Card ပေါ်မှာ ပြမယ့် အကျဉ်းချုပ် တစ်ကြောင်း။
  final String subtitle;

  /// အသေးစိတ် စာမျက်နှာမှာ ပြမယ့် စာသား အပြည့်အစုံ။
  final String body;
  final List<String> images;
  final List<Treatment> treatments;

  /// လက်နဲ့ ဖြည့်ထားတဲ့ အပိုင်းများ (overlay ဖိုင်ကနေ ပူးတွဲလာတာ)။
  final List<DetailSection> sections;

  /// ရှာဖွေတဲ့အခါ ကြည့်မယ့် စာသားအားလုံး (ဆေးနာမည်တွေပါ ပါဝင်တယ် —
  /// တောင်သူက "Applaud" လို့ ရိုက်ရှာရင်လည်း ဘယ်ပိုးအတွက်လဲ တွေ့ရမယ်)။
  String get searchText => [
    title,
    subtitle,
    body,
    for (final t in treatments) '${t.name} ${t.usage}',
    for (final s in sections) '${s.title} ${[for (final p in s.points) '${p.label} ${p.detail}'].join(' ')}',
  ].join(' ').toLowerCase();

  /// Overlay ဖိုင်ထဲက အချက်အလက်တွေ ပူးတွဲပြီး item အသစ် ပြန်ဆောက်တယ်။
  ResourceItem withDetails({String? title, List<DetailSection> sections = const []}) => ResourceItem(
    kind: kind,
    title: title ?? this.title,
    subtitle: subtitle,
    body: body,
    images: images,
    treatments: treatments,
    sections: [...this.sections, ...sections],
  );

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    return q.isEmpty || searchText.contains(q);
  }
}

/// မြေဩဇာ ကျွေးရမယ့် အချိန်ဇယား တစ်တန်း။
class FertiliserStage {
  const FertiliserStage({
    required this.stage,
    required this.age,
    required this.urea,
    required this.phosphate,
    required this.potash,
    required this.purpose,
  });

  final String stage;
  final String age;
  final String urea;
  final String phosphate;
  final String potash;
  final String purpose;

  factory FertiliserStage.fromJson(Map<String, dynamic> json) => FertiliserStage(
    stage: (json['stage'] ?? '').toString().trim(),
    age: (json['age'] ?? '').toString().trim(),
    urea: (json['urea'] ?? '-').toString().trim(),
    phosphate: (json['phosphate'] ?? '-').toString().trim(),
    potash: (json['potash'] ?? '-').toString().trim(),
    purpose: (json['purpose'] ?? '').toString().trim(),
  );
}

/// JSON တစ်ခုလုံးကို ဖတ်ပြီး ပြင်ဆင်ပြီးသား စာရင်းတွေ ပြန်ပေးတယ်။
class ResourceLibrary {
  const ResourceLibrary({required this.items, required this.schedule});

  final List<ResourceItem> items;
  final List<FertiliserStage> schedule;

  static const ResourceLibrary empty = ResourceLibrary(items: [], schedule: []);

  List<ResourceItem> of(ResourceKind kind) => [
    for (final item in items)
      if (item.kind == kind) item,
  ];

  List<ResourceItem> search(String query) => [
    for (final item in items)
      if (item.matches(query)) item,
  ];

  /// Overlay ဖိုင် (`resource_details.json`) ကို ပူးတွဲတယ်။
  ///
  /// Key ကို item ခေါင်းစဉ်ထဲ ပါ/မပါ နဲ့ တိုက်စစ်တာမို့ "ကောမက်" တစ်လုံးတည်းနဲ့
  /// "ကောမက်(ပုလဲ / ယူရီးယား)" ကို မိတယ် — စာရွက်စာတမ်းထဲက ခေါင်းစဉ် အနည်းငယ်
  /// ပြောင်းသွားလည်း ချိတ်မိနေအောင်။
  ResourceLibrary mergeDetails(Map<String, dynamic> overlay) {
    final details = overlay['details'];
    if (details is! Map<String, dynamic> || details.isEmpty) return this;

    return ResourceLibrary(
      schedule: schedule,
      items: [
        for (final item in items) _applyDetails(item, details),
      ],
    );
  }

  static ResourceItem _applyDetails(ResourceItem item, Map<String, dynamic> details) {
    for (final entry in details.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      if (!item.title.contains(entry.key)) continue;
      return item.withDetails(
        title: (value['title'] as String?)?.trim(),
        sections: [
          for (final s in (value['sections'] as List? ?? const []))
            if (s is Map<String, dynamic>) DetailSection.fromJson(s),
        ],
      );
    }
    return item;
  }

  factory ResourceLibrary.fromJson(Map<String, dynamic> json) {
    final items = <ResourceItem>[];

    for (final raw in (json['pests'] as List? ?? const [])) {
      if (raw is! Map<String, dynamic>) continue;
      final treatments = [
        for (final t in (raw['treatments'] as List? ?? const []))
          if (t is Map<String, dynamic>) Treatment.fromJson(t),
      ];
      items.add(
        ResourceItem(
          kind: ResourceKind.pest,
          title: (raw['name'] ?? '').toString().trim(),
          // ဆေးမည်မျှ ရှိလဲ ဆိုတာ card ပေါ်မှာ ချက်ချင်း မြင်ရအောင်။
          subtitle: (raw['symptom'] ?? '').toString().trim(),
          body: (raw['symptom'] ?? '').toString().trim(),
          images: _strings(raw['images']),
          treatments: treatments,
        ),
      );
    }

    for (final raw in (json['fertiliserBrands'] as List? ?? const [])) {
      if (raw is! Map<String, dynamic>) continue;
      items.add(
        ResourceItem(
          kind: ResourceKind.fertiliser,
          title: (raw['name'] ?? '').toString().trim(),
          subtitle: (raw['detail'] ?? '').toString().trim(),
          body: (raw['detail'] ?? '').toString().trim(),
          images: _strings(raw['images']),
        ),
      );
    }


    for (final raw in (json['growthStages'] as List? ?? const [])) {
      if (raw is! Map<String, dynamic>) continue;
      items.add(
        ResourceItem(
          kind: ResourceKind.growthStage,
          title: (raw['title'] ?? '').toString().trim(),
          subtitle: (raw['detail'] ?? '').toString().trim(),
          body: (raw['detail'] ?? '').toString().trim(),
          images: _strings(raw['images']),
        ),
      );
    }

    for (final raw in (json['guidelines'] as List? ?? const [])) {
      if (raw is! Map<String, dynamic>) continue;
      items.add(
        ResourceItem(
          kind: ResourceKind.guideline,
          title: (raw['title'] ?? '').toString().trim(),
          subtitle: (raw['detail'] ?? '').toString().trim(),
          body: (raw['detail'] ?? '').toString().trim(),
          images: const [],
        ),
      );
    }


    return ResourceLibrary(
      items: items,
      schedule: [
        for (final raw in (json['fertiliserSchedule'] as List? ?? const []))
          if (raw is Map<String, dynamic>) FertiliserStage.fromJson(raw),
      ],
    );
  }
}

List<String> _strings(Object? raw) => [
  for (final v in (raw as List? ?? const [])) v.toString(),
];
