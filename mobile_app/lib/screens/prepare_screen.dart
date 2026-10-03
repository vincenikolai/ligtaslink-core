import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class _Item {
  final String id;
  final String label;
  const _Item(this.id, this.label);
}

const _sections = <(String, IconData, List<_Item>)>[
  ('Evacuation center readiness', Icons.inventory_2, [
    _Item('ec-roster', 'Device seeded with the Barangay 33-D household roster (500 households)'),
    _Item('ec-qr', 'Printed household QR relief cards distributed per purok'),
    _Item('ec-stock', 'Relief pack inventory counted and logged at the distribution desk'),
    _Item('ec-power', 'Power banks or generator charged for scanning devices'),
    _Item('ec-health', 'Health desk set up for PWD, senior and pregnant residents'),
    _Item('ec-water', 'Potable water supply estimated at 15 L per person per day'),
    _Item('ec-space', 'Shelter space mapped at 3.5 m² per person'),
  ]),
  ('Frontline worker kit', Icons.badge, [
    _Item('fw-id', 'Worker ID and barangay authorization on hand'),
    _Item('fw-key', 'Worker key registered with the Dual-Sync Daemon before deployment'),
    _Item('fw-radio', 'Two-way radio or backup phone with Central 911 saved'),
    _Item('fw-light', 'Flashlight, whistle and reflective vest'),
  ]),
  ('Family go-bag (advice for residents)', Icons.backpack, [
    _Item('gb-docs', 'Copies of IDs and the household QR relief card in a waterproof pouch'),
    _Item('gb-food', 'Three days of ready-to-eat food and drinking water'),
    _Item('gb-meds', 'Maintenance medicines and a first-aid kit'),
    _Item('gb-clothes', 'Change of clothes, blanket and rain gear'),
    _Item('gb-cash', 'Small bills and coins for emergencies'),
  ]),
];

class PrepareScreen extends StatefulWidget {
  const PrepareScreen({super.key});

  @override
  State<PrepareScreen> createState() => _PrepareScreenState();
}

class _PrepareScreenState extends State<PrepareScreen> {
  final Map<String, bool> _checked = {};
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _load(AppScope.of(context));
    }
  }

  Future<void> _load(AppController app) async {
    final values = <String, bool>{};
    for (final section in _sections) {
      for (final item in section.$3) {
        values[item.id] = await app.db.getMeta('prepare:${item.id}') == 'true';
      }
    }
    if (mounted) setState(() => _checked.addAll(values));
  }

  Future<void> _toggle(AppController app, String id, bool value) async {
    setState(() => _checked[id] = value);
    await app.db.setMeta('prepare:$id', '$value');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final total = _sections.fold<int>(0, (n, s) => n + s.$3.length);
    final done = _checked.values.where((v) => v).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
      children: [
        const Text('Preparedness Checklist', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const Text('Saved on this device, works offline', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        SurfaceCard(
          child: Row(children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                value: total == 0 ? 0 : done / total,
                strokeWidth: 6,
                color: done == total ? AppColors.success : AppColors.brand,
                backgroundColor: AppColors.brandTint,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text('$done of $total items ready',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        for (final section in _sections) ...[
          const SizedBox(height: 16),
          SurfaceCard(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(children: [
                  Icon(section.$2, color: AppColors.brand),
                  const SizedBox(width: 8),
                  Expanded(child: SectionTitle(section.$1)),
                ]),
              ),
              for (final item in section.$3)
                CheckboxListTile(
                  value: _checked[item.id] ?? false,
                  activeColor: AppColors.brand,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(item.label),
                  onChanged: (v) => _toggle(app, item.id, v ?? false),
                ),
            ]),
          ),
        ],
      ],
    );
  }
}
