import 'package:flutter/material.dart';

import '../widgets/batch_card.dart';
import '../widgets/household_search.dart';
import '../widgets/live_log_table.dart';
import '../widgets/quick_service_row.dart';
import '../widgets/scanner_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.desktop});
  final bool desktop;

  @override
  Widget build(BuildContext context) => desktop ? _desktop() : _mobile();

  Widget _desktop() => SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              HouseholdSearch(),
              SizedBox(height: 20),
              QuickServiceRow(),
              SizedBox(height: 20),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 380,
                  child: Column(children: [ScannerCard(), SizedBox(height: 20), BatchCard()]),
                ),
                SizedBox(width: 20),
                Expanded(child: LiveLogTable()),
              ]),
            ]),
          ),
        ),
      );

  Widget _mobile() => const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 96),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ScannerCard(),
          SizedBox(height: 16),
          HouseholdSearch(),
          SizedBox(height: 16),
          QuickServiceRow(),
          SizedBox(height: 16),
          BatchCard(),
          SizedBox(height: 16),
          LiveLogTable(compact: true, limit: 15),
        ]),
      );
}
