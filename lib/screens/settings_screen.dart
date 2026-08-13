import 'package:flutter/cupertino.dart';

import '../l10n/app_strings.dart';
import '../services/plant_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import 'root_shell.dart';

/// Settings tab — ESP32 ရဲ့ IP/port နဲ့ app ဘာသာစကားကို ဒီကနေ ပြောင်းနိုင်တယ်။
/// (မှတ်ချက်: ယခုအဆင့်မှာ memory ထဲသာ သိမ်းတာမို့ app ပိတ်ရင် default ပြန်ဖြစ်တယ်။)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PlantService _service = PlantService.instance;
  late final TextEditingController _hostController = TextEditingController(text: _service.host);
  late final TextEditingController _portController = TextEditingController(text: '${_service.streamPort}');

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _save(AppStrings s) {
    _service.updateHost(_hostController.text, port: int.tryParse(_portController.text.trim()));
    FocusScope.of(context).unfocus();
    _alert(
      title: s.savedTitle,
      message: s.savedMessage(_service.host, _service.streamPort),
      okLabel: s.ok,
    );
  }

  /// Test connection — ရလဒ်ကို စောင့်ပြီး အောင်/မအောင် dialog နဲ့ အသိပေးတယ်။
  /// (အရင်က refresh ကို fire-and-forget ခေါ်တာမို့ ဘာဖြစ်သွားလဲ မသိရဘူး။)
  Future<void> _testConnection(AppStrings s) async {
    FocusScope.of(context).unfocus();
    await _service.refresh();
    if (!mounted) return;
    final error = _service.lastError;
    _alert(
      title: error == null ? s.connectedTitle : s.connectionFailedTitle,
      message: error == null
          ? s.connectedMessage(_service.dataUrl)
          : s.connectionError(error, host: _service.host, statusCode: _service.lastErrorStatusCode),
      okLabel: s.ok,
    );
  }

  void _alert({required String title, required String message, required String okLabel}) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx), child: Text(okLabel))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.of(context);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: Text(s.settingsTitle, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.label)),
      ),
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _service,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, kNavBarClearance),
            children: [
              _sectionLabel(s.languageSection),
              _card(child: const _LanguagePicker()),
              const SizedBox(height: 6),
              _footnote(s.languageFooter),
              const SizedBox(height: 20),
              _sectionLabel(s.deviceSection),
              _card(
                child: Column(
                  children: [
                    _field(label: s.hostField, controller: _hostController, keyboardType: TextInputType.url, placeholder: '192.168.1.50'),
                    const AppSeparator(indent: 14),
                    _field(label: s.portField, controller: _portController, keyboardType: TextInputType.number, placeholder: '8080'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: CupertinoButton(
                  color: AppColors.green,
                  borderRadius: AppRadius.tile,
                  padding: EdgeInsets.zero,
                  onPressed: () => _save(s),
                  child: Text(
                    s.saveDeviceSettings,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: CupertinoColors.white),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _sectionLabel(s.connectionSection),
              _card(
                child: Column(
                  children: [
                    _row(icon: CupertinoIcons.link, title: s.dataEndpoint, value: _service.dataUrl, color: AppColors.blue),
                    const AppSeparator(indent: 14),
                    _row(icon: CupertinoIcons.videocam, title: s.streamEndpoint, value: _service.streamUrl, color: AppColors.purple),
                    const AppSeparator(indent: 14),
                    _row(
                      icon: _service.lastError == null && _service.hasData ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.exclamationmark_circle,
                      title: s.lastSync,
                      value: _service.lastError == null
                          ? s.lastUpdatedLabel(_service.lastUpdated)
                          : s.connectionError(_service.lastError!, host: _service.host, statusCode: _service.lastErrorStatusCode),
                      color: _service.lastError == null && _service.hasData ? AppColors.green : AppColors.orange,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Secondary button — card အဖြူပေါ်မှာ border ခြယ်ထားတာမို့
              // page background (grey) နဲ့ မရောဘဲ initial state မှာကတည်းက မြင်ရတယ်။
              Container(
                height: 48,
                decoration: BoxDecoration(color: AppColors.card, borderRadius: AppRadius.tile, boxShadow: AppShadow.card),
                child: CupertinoButton(
                  borderRadius: BorderRadius.circular(14),
                  padding: EdgeInsets.zero,
                  onPressed: _service.isLoading ? null : () => _testConnection(s),
                  child: _service.isLoading
                      ? const CupertinoActivityIndicator()
                      : Text(
                          s.testConnection,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.blue),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(s.appVersion, style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryLabel)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppColors.secondaryLabel),
      ),
    );
  }

  Widget _footnote(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.secondaryLabel, height: 1.3)),
    );
  }

  Widget _card({required Widget child}) => AppCard.rows(children: [child]);

  Widget _field({required String label, required TextEditingController controller, required TextInputType keyboardType, required String placeholder}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14.5, color: AppColors.label),
            ),
          ),
          Expanded(
            flex: 5,
            child: CupertinoTextField(
              controller: controller,
              keyboardType: keyboardType,
              placeholder: placeholder,
              textAlign: TextAlign.right,
              decoration: null,
              style: const TextStyle(fontSize: 14.5, color: AppColors.secondaryLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row({required IconData icon, required String title, required String value, required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          IconChip(icon: icon, color: color, size: 30),
          const SizedBox(width: 11),
          Expanded(
            flex: 4,
            child: Text(
              title,
              style: const TextStyle(fontSize: 14.5, color: AppColors.label),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.secondaryLabel),
            ),
          ),
        ],
      ),
    );
  }
}

/// English / မြန်မာ ရွေးချယ်ရန် segmented control။
/// ရွေးလိုက်တာနဲ့ [LocaleController] က notify လုပ်ပြီး app တစ်ခုလုံး ဘာသာပြန်သွားတယ်။
class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker();

  @override
  Widget build(BuildContext context) {
    final current = AppLocale.languageOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          const IconChip(icon: CupertinoIcons.globe, color: AppColors.blue, size: 30),
          const SizedBox(width: 11),
          Expanded(
            // အမြင့်ကို ပုံသေမထားပါ — မြန်မာစာလုံးတွေက အင်္ဂလိပ်ထက် မြင့်တာမို့
            // SizedBox(height: 32) ထားရင် segmented control က overflow ဖြစ်တယ်။
            child: CupertinoSlidingSegmentedControl<AppLanguage>(
              groupValue: current,
              padding: const EdgeInsets.all(3),
              onValueChanged: (value) {
                if (value != null) LocaleController.instance.setLanguage(value);
              },
              children: {
                for (final language in AppLanguage.values)
                  language: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      language.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: language == current ? FontWeight.w600 : FontWeight.w400,
                        color: AppColors.label,
                      ),
                    ),
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }
}


