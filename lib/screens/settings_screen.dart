import 'package:flutter/cupertino.dart';

import '../services/plant_service.dart';
import '../theme/app_colors.dart';
import 'root_shell.dart';

/// Settings tab — ESP32 ရဲ့ IP/port ကို app ထဲကနေတိုက်ရိုက် ပြောင်းနိုင်တယ်။
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

  void _save() {
    _service.updateHost(_hostController.text, port: int.tryParse(_portController.text.trim()));
    FocusScope.of(context).unfocus();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Saved'),
        content: Text('Now using ${_service.host} for sensor data and port ${_service.streamPort} for the camera stream.'),
        actions: [CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Settings', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.label)),
      ),
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _service,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, kNavBarClearance),
            children: [
              _sectionLabel('DEVICE'),
              _card(
                child: Column(
                  children: [
                    _field(label: 'ESP32 host / IP', controller: _hostController, keyboardType: TextInputType.url, placeholder: '192.168.1.50'),
                    const _Separator(),
                    _field(label: 'Camera stream port', controller: _portController, keyboardType: TextInputType.number, placeholder: '8080'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: CupertinoButton(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(14),
                  padding: EdgeInsets.zero,
                  onPressed: _save,
                  child: const Text('Save device settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 24),
              _sectionLabel('CONNECTION'),
              _card(
                child: Column(
                  children: [
                    _row(icon: CupertinoIcons.link, title: 'Data endpoint', value: _service.dataUrl, color: AppColors.blue),
                    const _Separator(),
                    _row(icon: CupertinoIcons.videocam, title: 'Stream endpoint', value: _service.streamUrl, color: AppColors.purple),
                    const _Separator(),
                    _row(
                      icon: _service.lastError == null && _service.hasData ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.exclamationmark_circle,
                      title: 'Last sync',
                      value: _service.lastError ?? _service.lastUpdatedLabel,
                      color: _service.lastError == null && _service.hasData ? AppColors.green : AppColors.orange,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: CupertinoButton(
                  color: AppColors.fill,
                  borderRadius: BorderRadius.circular(14),
                  padding: EdgeInsets.zero,
                  onPressed: _service.isLoading ? null : _service.refresh,
                  child: _service.isLoading
                      ? const CupertinoActivityIndicator()
                      : const Text(
                          'Test connection',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.label),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              _sectionLabel('CARE THRESHOLDS'),
              _card(
                child: Column(
                  children: [
                    _row(icon: CupertinoIcons.leaf_arrow_circlepath, title: 'Nitrogen minimum', value: '${PlantService.nMin} mg/kg', color: AppColors.green),
                    const _Separator(),
                    _row(icon: CupertinoIcons.leaf_arrow_circlepath, title: 'Phosphorus minimum', value: '${PlantService.pMin} mg/kg', color: AppColors.green),
                    const _Separator(),
                    _row(icon: CupertinoIcons.leaf_arrow_circlepath, title: 'Potassium minimum', value: '${PlantService.kMin} mg/kg', color: AppColors.green),
                    const _Separator(),
                    _row(icon: CupertinoIcons.sun_max, title: 'Light minimum', value: '${PlantService.lightMin.toStringAsFixed(0)} lux', color: AppColors.orange),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text('Plant Monitoring · v1.0.0', style: TextStyle(fontSize: 12.5, color: AppColors.secondaryLabel)),
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
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: AppColors.secondaryLabel),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator),
      ),
      child: child,
    );
  }

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
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 15, color: color),
          ),
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

/// Cupertino app မှာ Material ရဲ့ Divider မသုံးနိုင်တာမို့ hairline separator ကို ကိုယ်တိုင်လုပ်ထားတယ်။
class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, margin: const EdgeInsets.only(left: 14), color: AppColors.separator);
  }
}
