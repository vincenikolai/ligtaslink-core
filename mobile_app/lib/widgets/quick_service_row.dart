import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'dialogs.dart';
import 'scan_actions.dart';

/// Sphere Handbook minimums used for planning estimates.
const _waterLitresPerPersonPerDay = 15;
const _shelterSqmPerPerson = 3.5;

class QuickServiceRow extends StatelessWidget {
  const QuickServiceRow({super.key});

  @override
  Widget build(BuildContext context) {
    final services = <(IconData, String, void Function(BuildContext))>[
      (Icons.verified_user, 'Verify', startScan),
      (Icons.local_shipping, 'Relief', _showRelief),
      (Icons.medical_services, 'Medical', _showMedical),
      (Icons.water_drop, 'Water', _showWater),
      (Icons.house, 'Shelter', _showShelter),
      (Icons.emergency, 'Emergency', showSosDialog),
    ];
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(left: 8), child: SectionTitle('Quick Relief Services')),
        LayoutBuilder(builder: (context, constraints) {
          final buttons = [for (final s in services) _ServiceButton(icon: s.$1, label: s.$2, onTap: () => s.$3(context))];
          // Fit all six in one row when wide enough; otherwise scroll horizontally.
          return constraints.maxWidth >= 6 * 84
              ? Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: buttons)
              : SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: buttons));
        }),
      ]),
    );
  }
}

class _ServiceButton extends StatelessWidget {
  const _ServiceButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 84,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle, boxShadow: AppTheme.cardShadow),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
            ]),
          ),
        ),
      );
}

void _showRelief(BuildContext context) {
  final app = AppScope.of(context);
  final stats = app.purokStats();
  showInfoSheet(context,
      icon: Icons.local_shipping,
      title: 'Relief Distribution Progress',
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${app.counts['items'] ?? 0} relief pack(s) released across ${app.counts['logs'] ?? 0} claim(s). '
            'Households served within the ${AppController.claimCooldown.inHours}-hour cycle:'),
        const SizedBox(height: 12),
        for (final s in stats)
          InfoRow(
            title: 'Purok ${s.purok}',
            subtitle: '${s.households - s.served} household(s) still waiting',
            value: '${s.served} / ${s.households}',
          ),
      ]));
}

void _showMedical(BuildContext context) {
  final app = AppScope.of(context);
  final priority = app.residents.where((r) => r.flags.any).toList()
    ..sort((a, b) => b.flags.labels.length.compareTo(a.flags.labels.length));
  showInfoSheet(context,
      icon: Icons.medical_services,
      title: 'Medical Priority List',
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${priority.length} household(s) with PWD, senior, or pregnant members. '
            'Route these to the health desk first.'),
        const SizedBox(height: 12),
        for (final r in priority)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.familyHeadName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${r.householdId} • Purok ${r.addressPurok}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                ),
                Wrap(spacing: 4, children: [for (final f in r.flags.labels) StatusBadge(f, tone: BadgeTone.brand)]),
                const SizedBox(width: 8),
                app.servedRecently.contains(r.householdId)
                    ? const Icon(Icons.check_circle, color: AppColors.success)
                    : const Icon(Icons.schedule, color: AppColors.textSecondary),
              ]),
            ),
          ),
      ]));
}

void _showWater(BuildContext context) {
  final app = AppScope.of(context);
  final stats = app.purokStats();
  showInfoSheet(context,
      icon: Icons.water_drop,
      title: 'Daily Water Requirement',
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Planning estimate at the Sphere minimum of $_waterLitresPerPersonPerDay L per person per day. '
            'Barangay total: ${app.totalPersons * _waterLitresPerPersonPerDay} L/day for ${app.totalPersons} residents.'),
        const SizedBox(height: 12),
        for (final s in stats)
          InfoRow(title: 'Purok ${s.purok}', subtitle: '${s.persons} residents', value: '${s.persons * _waterLitresPerPersonPerDay} L'),
      ]));
}

void _showShelter(BuildContext context) {
  final app = AppScope.of(context);
  final stats = app.purokStats();
  String sqm(int persons) => (persons * _shelterSqmPerPerson).toStringAsFixed(0);
  showInfoSheet(context,
      icon: Icons.house,
      title: 'Evacuation Shelter Space',
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Covered living space needed at the Sphere minimum of $_shelterSqmPerPerson m² per person. '
            'Barangay total: ${sqm(app.totalPersons)} m².'),
        const SizedBox(height: 12),
        for (final s in stats)
          InfoRow(title: 'Purok ${s.purok}', subtitle: '${s.persons} residents • ${s.vulnerable} vulnerable household(s)', value: '${sqm(s.persons)} m²'),
      ]));
}
