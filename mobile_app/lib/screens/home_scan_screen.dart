import 'package:flutter/material.dart';
import '../main.dart';
import 'dashboard_screen.dart';

class HomeScanScreen extends StatefulWidget {
  const HomeScanScreen({super.key});
  @override
  State<HomeScanScreen> createState() => _HomeScanScreenState();
}

class _HomeScanScreenState extends State<HomeScanScreen> {
  int queue = 0;
  String scanLabel = 'Long press to verify relief';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 900;
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              if (desktop) _Sidebar(onDashboard: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DashboardScreen()))),
              Expanded(
                child: Column(
                  children: [
                    _Header(desktop: desktop),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: desktop ? 44 : 20,
                          vertical: 28,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SearchBar(),
                              const SizedBox(height: 28),
                              const Text('Quick relief service',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: kInk)),
                              const SizedBox(height: 16),
                              _ServiceRow(desktop: desktop),
                              const SizedBox(height: 32),
                              Wrap(
                                spacing: 22,
                                runSpacing: 22,
                                children: [
                                  SizedBox(
                                    width: desktop ? 440 : constraints.maxWidth - 40,
                                    child: _ScannerCard(
                                      label: scanLabel,
                                      onScan: () => setState(() {
                                        queue++;
                                        scanLabel = 'Verified - 1 relief pack allocated';
                                      }),
                                    ),
                                  ),
                                  SizedBox(
                                    width: desktop ? 440 : constraints.maxWidth - 40,
                                    child: _QueueCard(queue: queue),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              const Text('Relief distribution updates',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: kInk)),
                              const SizedBox(height: 14),
                              _UpdatesGrid(desktop: desktop),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _Header extends StatelessWidget {
  final bool desktop;
  const _Header({required this.desktop});
  @override
  Widget build(BuildContext context) => Container(
        height: 74,
        color: kOrange,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            if (!desktop)
              IconButton(
                  onPressed: () {},
                  color: Colors.white,
                  icon: const Icon(Icons.menu)),
            const Icon(Icons.volunteer_activism, color: Colors.white),
            const SizedBox(width: 10),
            const Text('LigtasLink',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20)),
            const Spacer(),
            const Icon(Icons.cloud_off, color: Colors.white70, size: 18),
            const SizedBox(width: 6),
            const Text('Offline ready',
                style: TextStyle(color: Colors.white, fontSize: 13)),
            const SizedBox(width: 18),
            const CircleAvatar(
                radius: 17,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: kOrange, size: 19)),
          ],
        ),
      );
}

class _Sidebar extends StatelessWidget {
  final VoidCallback onDashboard;
  const _Sidebar({required this.onDashboard});
  @override
  Widget build(BuildContext context) => Container(
        width: 210,
        color: Colors.white,
        child: Column(
          children: [
            Container(
              height: 74,
              color: kOrangeDark,
              padding: const EdgeInsets.all(18),
              child: const Row(children: [
                Icon(Icons.shield_outlined, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                    child: Text('DISASTER\nMANAGEMENT',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12)))
              ]),
            ),
            const SizedBox(height: 26),
            _NavItem(icon: Icons.home_outlined, label: 'Home', active: true),
            _NavItem(
                icon: Icons.dashboard_outlined,
                label: 'Dashboard',
                onTap: onDashboard),
            const _NavItem(icon: Icons.inventory_2_outlined, label: 'Prepare'),
            const _NavItem(icon: Icons.notifications_none, label: 'Alerts'),
            const _NavItem(icon: Icons.help_outline, label: 'Advice'),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Card(
                color: const Color(0xFFFFF1EB),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(children: [
                    const CircleAvatar(
                        backgroundColor: kOrange,
                        child: Icon(Icons.sos, color: Colors.white)),
                    const SizedBox(height: 10),
                    const Text('Emergency support',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    FilledButton(
                        onPressed: () {},
                        style: FilledButton.styleFrom(
                            backgroundColor: kOrange,
                            minimumSize: const Size.fromHeight(34)),
                        child: const Text('Open SOS'))
                  ]),
                ),
              ),
            ),
          ],
        ),
      );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _NavItem(
      {required this.icon, required this.label, this.active = false, this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        dense: true,
        leading: Icon(icon, color: active ? kOrange : Colors.grey.shade600),
        title: Text(label,
            style: TextStyle(
                color: active ? kOrange : Colors.grey.shade700,
                fontWeight: active ? FontWeight.bold : FontWeight.w500)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
}

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const TextField(
          decoration: InputDecoration(
              hintText: 'Search household, purok, or relief record',
              prefixIcon: Icon(Icons.search),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14)),
        ),
      );
}

class _ServiceRow extends StatelessWidget {
  final bool desktop;
  const _ServiceRow({required this.desktop});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: const [
            _Service(icon: Icons.qr_code_scanner, label: 'Verify'),
            _Service(icon: Icons.local_shipping_outlined, label: 'Relief'),
            _Service(icon: Icons.local_hospital_outlined, label: 'Medical'),
            _Service(icon: Icons.water_drop_outlined, label: 'Water'),
            _Service(icon: Icons.home_work_outlined, label: 'Shelter'),
            _Service(icon: Icons.warning_amber, label: 'Emergency'),
          ],
        ),
      );
}

class _Service extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Service({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 24),
        child: Column(children: [
          CircleAvatar(
              radius: 26,
              backgroundColor: kOrange,
              child: Icon(icon, color: Colors.white)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600))
        ]),
      );
}

class _ScannerCard extends StatelessWidget {
  final String label;
  final VoidCallback onScan;
  const _ScannerCard({required this.label, required this.onScan});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(children: [
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Household verification',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 18),
            Container(
              height: 150,
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF1EB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kOrange, width: 2)),
              child: const Center(
                  child: Icon(Icons.qr_code_2, size: 92, color: kOrange)),
            ),
            const SizedBox(height: 14),
            Text(label, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: onScan,
                    style: FilledButton.styleFrom(backgroundColor: kOrange),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR household card')))
          ]),
        ),
      );
}

class _QueueCard extends StatelessWidget {
  final int queue;
  const _QueueCard({required this.queue});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Offline sync status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 18),
            Row(children: [
              const CircleAvatar(
                  radius: 29,
                  backgroundColor: Color(0xFFFFE0D2),
                  child: Icon(Icons.cloud_off, color: kOrange)),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$queue pending records',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const Text('Saved securely on this device')
              ])
            ]),
            const SizedBox(height: 22),
            const LinearProgressIndicator(
                value: .72,
                color: kOrange,
                backgroundColor: Color(0xFFFFE4D9)),
            const SizedBox(height: 10),
            const Text('Merkle batch height 4  •  R_offline ready',
                style: TextStyle(color: Colors.black54))
          ]),
        ),
      );
}

class _UpdatesGrid extends StatelessWidget {
  final bool desktop;
  const _UpdatesGrid({required this.desktop});
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 18,
        runSpacing: 18,
        children: const [
          _UpdateCard(title: 'Relief distribution', detail: 'Purok 1 • 35 families served', icon: Icons.inventory_2_outlined),
          _UpdateCard(title: 'Medical assistance', detail: 'Purok 4 • First aid station open', icon: Icons.medical_services_outlined),
          _UpdateCard(title: 'Water station', detail: 'Purok 6 • Available until 6:00 PM', icon: Icons.water_drop_outlined),
        ],
      );
}

class _UpdateCard extends StatelessWidget {
  final String title;
  final String detail;
  final IconData icon;
  const _UpdateCard({required this.title, required this.detail, required this.icon});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 260,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              CircleAvatar(
                  backgroundColor: const Color(0xFFFFE1D4),
                  child: Icon(icon, color: kOrange)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text(detail,
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12))
                  ]))
            ]),
          ),
        ),
      );
}
