import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/resource_item.dart';

/// `assets/data/resources.json` ကို တစ်ခါပဲ ဖတ်ပြီး cache ထားတယ်။
///
/// AI Scan tab က tab ပြောင်းတိုင်း rebuild ဖြစ်ပေမယ့် ဖိုင်ကို ထပ်ခါထပ်ခါ
/// မဖတ်တော့ဘူး — [load] က future တစ်ခုတည်းကိုပဲ ပြန်ပေးတယ်။
class ResourceService {
  ResourceService._();

  static final ResourceService instance = ResourceService._();

  Future<ResourceLibrary>? _pending;

  Future<ResourceLibrary> load() => _pending ??= _read();

  Future<ResourceLibrary> _read() async {
    try {
      final raw = await rootBundle.loadString('assets/data/resources.json');
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) return ResourceLibrary.empty;
      final library = ResourceLibrary.fromJson(decoded);

      // လက်နဲ့ ဖြည့်ထားတဲ့ အသေးစိတ်တွေ ပူးတွဲတယ်။ ဒီဖိုင်က ဖတ်လို့ မရရင်လည်း
      // စာရွက်စာတမ်းကနေ ထုတ်ထားတဲ့ အချက်အလက်တွေကတော့ ဆက်ရမယ်။
      try {
        final overlayRaw = await rootBundle.loadString('assets/data/resource_details.json');
        final overlay = json.decode(overlayRaw);
        if (overlay is Map<String, dynamic>) return library.mergeDetails(overlay);
      } catch (_) {
        // overlay မရှိရင် ကျော်သွားရုံပါပဲ။
      }
      return library;
    } catch (_) {
      // Asset မပါလာရင် (ဒါမှမဟုတ် JSON ပျက်နေရင်) app က မကျဘဲ
      // အရင်းအမြစ် အပိုင်းကိုပဲ ချန်ထားပြီး ဆက်အလုပ်လုပ်ပါစေ။
      _pending = null;
      return ResourceLibrary.empty;
    }
  }
}
