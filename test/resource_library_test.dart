import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plant_monitoring/models/resource_item.dart';

/// `tool/extract_resources.py` ထုတ်ပေးတဲ့ asset ကို app က မှန်မှန်ကန်ကန်
/// ဖတ်နိုင်ရဲ့လား စစ်တယ် — စာရွက်စာတမ်း ပြင်ပြီး script ပြန်ဖွင့်တဲ့အခါ
/// ဖွဲ့စည်းပုံ ပျက်သွားရင် ဒီ test က အရင်ဆုံး ဖမ်းပေးလိမ့်မယ်။
void main() {
  final raw = File('assets/data/resources.json').readAsStringSync();
  final overlayRaw = File('assets/data/resource_details.json').readAsStringSync();
  final library = ResourceLibrary.fromJson(
    json.decode(raw) as Map<String, dynamic>,
  ).mergeDetails(json.decode(overlayRaw) as Map<String, dynamic>);

  test('loads every category from the generated asset', () {
    expect(library.of(ResourceKind.pest), hasLength(12));
    expect(library.of(ResourceKind.fertiliser), isNotEmpty);
    expect(library.of(ResourceKind.guideline), hasLength(3));
    expect(library.schedule, hasLength(3));
  });

  test('crop stages come from the document, varieties do not', () {
    expect(library.of(ResourceKind.growthStage), hasLength(5));
    // စပါးအမျိုးအစား ဇယားကို မထည့်တော့ဘူး — ဇယားထဲက မျိုးနာမည် ပေါ်နေရင်
    // extractor မှာ ကျန်နေသေးတယ် ဆိုတာ ပြတယ်။
    expect(library.search('မနောသုခ'), isEmpty);
    expect(library.search('ပေါ်ဆန်းမွှေး'), isEmpty);
  });

  test('every fertiliser brand and crop stage has a photo', () {
    for (final brand in library.of(ResourceKind.fertiliser)) {
      expect(brand.images, isNotEmpty, reason: '${brand.title} lost its bag photo');
    }
    for (final stage in library.of(ResourceKind.growthStage)) {
      expect(stage.images, hasLength(1), reason: '${stage.title} should show one field photo');
    }
  });

  test('a photo belongs to only one owner', () {
    // ပုံတစ်ပုံကို နှစ်နေရာမှာ ပြနေရင် တွဲမိမှု မှားနေပြီ။
    final owners = <String, List<String>>{};
    for (final item in library.items) {
      if (item.kind == ResourceKind.pest) continue; // ဆေးပုံတွေက အများသုံး
      for (final image in item.images) {
        owners.putIfAbsent(image, () => []).add(item.title);
      }
    }
    for (final entry in owners.entries) {
      expect(entry.value, hasLength(1), reason: '${entry.key} is shared by ${entry.value}');
    }
  });

  test('pests carry symptoms and numbered treatments', () {
    for (final pest in library.of(ResourceKind.pest)) {
      expect(pest.title, isNotEmpty, reason: 'pest without a name');
      expect(pest.body, isNotEmpty, reason: '${pest.title} has no symptom text');
      expect(pest.treatments, isNotEmpty, reason: '${pest.title} has no treatments');
      for (final t in pest.treatments) {
        expect(t.name, isNotEmpty);
        // အသုံးပြုပုံ မပါရင် တောင်သူအတွက် အသုံးမဝင်ဘူး။
        expect(t.usage, isNotEmpty, reason: '${pest.title} → ${t.name} has no usage');
      }
    }
  });

  test('every treatment carries exactly one product photo', () {
    final missing = <String>[];
    for (final pest in library.of(ResourceKind.pest)) {
      for (final t in pest.treatments) {
        // ဓာတ်ပုံက row ရဲ့ နံပါတ်နေရာကို အစားထိုးတာမို့ တစ်ပုံထက် မပိုသင့်ဘူး။
        expect(t.images.length, lessThanOrEqualTo(1), reason: '${t.name} has ${t.images.length} photos');
        if (t.images.isEmpty) missing.add('${pest.title} → ${t.name}');
      }
    }
    expect(missing, isEmpty, reason: 'treatments without a photo: $missing');
  });

  test('the same product shows the same photo under every pest', () {
    final photos = <String, Set<String>>{};
    for (final pest in library.of(ResourceKind.pest)) {
      for (final t in pest.treatments) {
        final key = t.name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
        photos.putIfAbsent(key, () => <String>{}).addAll(t.images);
      }
    }
    for (final entry in photos.entries) {
      expect(entry.value.length, lessThanOrEqualTo(1), reason: '${entry.key} has mixed photos: ${entry.value}');
    }
  });

  test('a treatment name is searchable from any category', () {
    final hits = library.search('applaud');
    expect(hits, isNotEmpty);
    expect(hits.every((i) => i.kind == ResourceKind.pest), isTrue);
  });

  test('search is case-insensitive and matches Burmese titles', () {
    expect(library.search('ARMO'), isNotEmpty);
    expect(library.search('ကောမက်'), isNotEmpty);
    expect(library.search('zzzz-not-here'), isEmpty);
  });

  test('hand-written detail is merged onto the Comet/urea brand', () {
    final komat = library.of(ResourceKind.fertiliser).firstWhere((i) => i.title.contains('ကောမက်'));
    expect(komat.title, contains('Comet'));
    expect(komat.sections, hasLength(3));
    // အကျိုးကျေးဇူး ၃ ချက် · ကျွေးရမည့်အကြိမ် ၃ ကြိမ် · နှုန်းထား ၄ ချက်
    expect(komat.sections.map((s) => s.points.length), [3, 3, 4]);
    expect(komat.sections.first.points.first.detail, isNotEmpty);
  });

  test('merged detail is searchable', () {
    // "သားတက်" က overlay ထဲမှာပဲ ရှိတယ် — စာရွက်စာတမ်းထဲမှာ မပါဘူး။
    final hits = library.search('သားတက်');
    expect(hits, isNotEmpty);
    expect(hits.first.title, contains('ကောမက်'));
  });

  test('every fertiliser brand carries hand-written detail', () {
    for (final brand in library.of(ResourceKind.fertiliser)) {
      expect(brand.sections, isNotEmpty, reason: '${brand.title} has no detail sections');
      for (final section in brand.sections) {
        expect(section.title, isNotEmpty);
        expect(section.points, isNotEmpty, reason: '${brand.title} → ${section.title} is empty');
        for (final point in section.points) {
          expect(point.label, isNotEmpty);
          expect(point.detail, isNotEmpty, reason: '${brand.title} → ${point.label} has no text');
        }
      }
    }
  });

  test('overlay titles replace the raw document headings', () {
    final titles = library.of(ResourceKind.fertiliser).map((i) => i.title).join(' | ');
    for (final expected in ['Comet', 'Zamani', 'MOP', 'Armo', 'Flying Horse', 'Top One', 'Hnin Pele']) {
      expect(titles, contains(expected));
    }
  });

  test('empty query returns everything', () {
    expect(library.search('   '), hasLength(library.items.length));
  });
}
