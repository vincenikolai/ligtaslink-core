import 'package:flutter/material.dart';

import '../models/resident.dart';
import '../services/app_controller.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'scan_actions.dart';

/// Search by family head, household ID, QR token, or "purok N".
/// Pressing Enter on an exact QR token verifies it directly (USB scanner friendly).
class HouseholdSearch extends StatefulWidget {
  const HouseholdSearch({super.key});

  @override
  State<HouseholdSearch> createState() => _HouseholdSearchState();
}

class _HouseholdSearchState extends State<HouseholdSearch> {
  final _controller = TextEditingController();
  List<Resident> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
        _controller.clear();
        _results = const [];
      });

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: AppTheme.cardShadow),
        child: TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'Search household, family head, purok, or QR token',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close), onPressed: _clear),
          ),
          onChanged: (q) => setState(() => _results = app.search(q)),
          onSubmitted: (q) {
            // Anything shaped like a QR token is verified, so forged or foreign cards
            // surface as NOT REGISTERED instead of an empty search.
            final token = q.trim().toUpperCase();
            if (token.startsWith('TOKEN-')) {
              _clear();
              verifyAndNotify(context, token);
            }
          },
        ),
      ),
      if (_results.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 6),
          decoration: AppTheme.card(),
          child: Material(type: MaterialType.transparency, child: Column(children: [
            for (final r in _results)
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.brandTint,
                  child: Text('P${r.addressPurok}', style: const TextStyle(fontSize: 10, color: AppColors.brand, fontWeight: FontWeight.w800)),
                ),
                title: Text(r.familyHeadName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${r.householdId} • ${r.qrToken} • ${r.householdSize} member(s)'),
                trailing: app.servedRecently.contains(r.householdId)
                    ? const StatusBadge('Served', tone: BadgeTone.success)
                    : TextButton.icon(
                        icon: const Icon(Icons.verified_user, size: 18),
                        label: const Text('Verify'),
                        onPressed: () {
                          _clear();
                          verifyAndNotify(context, r.qrToken);
                        },
                      ),
              ),
          ])),
        )
      else if (_controller.text.trim().isNotEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 8, left: 4),
          child: Text('No matching household in Barangay 33-D.', style: TextStyle(color: AppColors.textSecondary)),
        ),
    ]);
  }
}
