import 'package:flutter/material.dart';
import '../main.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Relief operations dashboard',
              style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Chip(
                  avatar: const Icon(Icons.verified, size: 17),
                  label: const Text('Blockchain audited'),
                  backgroundColor: Colors.white),
            )
          ],
        ),
        body: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
                  padding: EdgeInsets.all(constraints.maxWidth > 700 ? 36 : 18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Community overview',
                              style: TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 20),
                          Wrap(spacing: 16, runSpacing: 16, children: const [
                            _Metric(
                                title: 'Families registered',
                                value: '500',
                                icon: Icons.groups_outlined),
                            _Metric(
                                title: 'Relief packs served',
                                value: '326',
                                icon: Icons.inventory_2_outlined),
                            _Metric(
                                title: 'Vulnerable residents',
                                value: '115',
                                icon: Icons.accessibility_new),
                            _Metric(
                                title: 'Pending sync',
                                value: '12',
                                icon: Icons.cloud_off),
                          ]),
                          const SizedBox(height: 30),
                          const Text('Purok distribution status',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          Card(
                              child: Column(
                                  children: List.generate(
                                      6,
                                      (index) => _PurokRow(
                                          purok: index + 1,
                                          served: 42 + index * 7,
                                          total: 75 + index * 4)))),
                        ]),
                  ),
                )),
      );
}

class _Metric extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _Metric({required this.title, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: Card(
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  CircleAvatar(
                      backgroundColor: const Color(0xFFFFE1D4),
                      child: Icon(icon, color: kOrange)),
                  const SizedBox(width: 12),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(value,
                            style: const TextStyle(
                                fontSize: 25, fontWeight: FontWeight.w800)),
                        Text(title,
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 12))
                      ])
                ]))),
      );
}

class _PurokRow extends StatelessWidget {
  final int purok;
  final int served;
  final int total;
  const _PurokRow(
      {required this.purok, required this.served, required this.total});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(children: [
          CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFFFE1D4),
              child: Text('$purok',
                  style: const TextStyle(
                      color: kOrange, fontWeight: FontWeight.bold))),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Purok $purok',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 7),
                LinearProgressIndicator(
                    value: served / total,
                    color: kOrange,
                    backgroundColor: const Color(0xFFFFE5DC))
              ])),
          const SizedBox(width: 18),
          Text('$served / $total served',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          const Icon(Icons.verified, color: Colors.green, size: 20)
        ]),
      );
}
