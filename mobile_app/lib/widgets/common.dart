import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// White card with 1px #EEEEEE border and Offset(0, 2) / blur 4 shadow.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        decoration: AppTheme.card(),
        // Gives ListTiles/InkWells inside the card a Material to paint ink on.
        child: Material(type: MaterialType.transparency, child: Padding(padding: padding, child: child)),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

enum BadgeTone { success, error, warning, neutral, brand }

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, required this.tone, this.icon});
  final String label;
  final BadgeTone tone;
  final IconData? icon;

  Color get _color => switch (tone) {
        BadgeTone.success => AppColors.success,
        BadgeTone.error => AppColors.error,
        BadgeTone.warning => const Color(0xFFB45309),
        BadgeTone.neutral => AppColors.textSecondary,
        BadgeTone.brand => AppColors.brand,
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _color.withValues(alpha: 0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: _color), const SizedBox(width: 4)],
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis, style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.value, required this.icon, this.color = AppColors.brand, this.caption});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;

  @override
  Widget build(BuildContext context) => SurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              if (caption != null)
                Text(caption!, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );
}

String shortHash(String? hex, {int head = 10, int tail = 6}) {
  if (hex == null || hex.isEmpty) return '—';
  if (hex.length <= head + tail + 1) return hex;
  return '${hex.substring(0, head)}…${hex.substring(hex.length - tail)}';
}

String formatTime(DateTime t) {
  final local = t.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

String formatClock(DateTime t) {
  final local = t.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}
