import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ligtaslink_mobile/crypto/merkle_engine.dart';
import 'package:ligtaslink_mobile/database/db_helper.dart';
import 'package:ligtaslink_mobile/main.dart';
import 'package:ligtaslink_mobile/models/scan_result.dart';
import 'package:ligtaslink_mobile/services/app_controller.dart';
import 'package:path/path.dart' show join;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<AppController> bootController(WidgetTester tester) async {
  final controller = AppController();
  await tester.runAsync(controller.init);
  expect(controller.initError, isNull);
  return controller;
}

Future<void> pumpAt(WidgetTester tester, AppController controller, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(LigtasLinkApp(controller: controller));
  await tester.pump();
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    FlutterSecureStorage.setMockInitialValues({});
    await databaseFactory.deleteDatabase(join(await databaseFactory.getDatabasesPath(), 'ligtaslink_local.db'));
  });

  testWidgets('desktop layout: sidebar, status bar, scanner and live log', (tester) async {
    final app = await bootController(tester);
    await pumpAt(tester, app, const Size(1440, 1000));

    expect(app.residents.length, 500);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byIcon(Icons.health_and_safety), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget); // active Home uses the filled icon
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off), findsWidgets);
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    for (final icon in [Icons.verified_user, Icons.local_shipping, Icons.medical_services, Icons.water_drop, Icons.house, Icons.emergency]) {
      expect(find.byIcon(icon), findsWidgets);
    }
    expect(find.text('Live Distribution Log'), findsOneWidget);

    final ScanResult result = (await tester.runAsync(() => app.verifyToken('TOKEN-B33D-P2-001')))!;
    expect(result.status, ScanStatus.verified);
    expect(result.merkleRoot, startsWith('0x'));
    final repeat = (await tester.runAsync(() => app.verifyToken('TOKEN-B33D-P2-001')))!;
    expect(repeat.status, ScanStatus.alreadyClaimed);
    final unknown = (await tester.runAsync(() => app.verifyToken('TOKEN-FAKE-1')))!;
    expect(unknown.status, ScanStatus.unknownToken);
    await tester.pump();
    expect(find.text('VERIFIED'), findsNothing); // last scan shown is the unknown token
    expect(find.text('NOT REGISTERED'), findsOneWidget);
    expect(find.text('Offline Pending'), findsOneWidget);
    expect(app.pendingCount, 1);

    for (final page in ['Dashboard', 'Prepare', 'Alerts', 'Advice']) {
      await tester.tap(find.text(page).first);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.text('Advice & Help'), findsOneWidget);
    app.dispose();
  });

  testWidgets('mobile layout: AppBar, scanner-first column, notched bottom bar', (tester) async {
    final app = await bootController(tester);
    await pumpAt(tester, app, const Size(390, 844));

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(BottomAppBar), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Household Verification'), findsOneWidget);
    expect(find.text('NAVIGATION'), findsNothing); // no desktop sidebar

    await tester.tap(find.text('Dashboard'));
    await tester.pump();
    expect(find.text('Relief Operations Dashboard'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.help_outline).first);
    await tester.pump();
    expect(find.text('Advice & Help'), findsOneWidget);
    app.dispose();
  });

  test('tampering with a log row after signing changes R_cloud', () async {
    final db = DbHelper.instance;
    final leaves = await db.pendingLeaves();
    expect(leaves, isNotEmpty);
    final ids = leaves.map((l) => l.transactionId).toList();
    final checkpoint = (await db.loadCheckpoint())!;
    // Untampered: what the daemon recomputes from the uploaded rows equals R_offline.
    expect(toHex0x(MerkleEngine.merkleRoot(await db.logsFor(ids))), checkpoint.merkleRoot);

    final raw = await db.database;
    await raw.update('distribution_logs', {'items_received': 99}, where: 'transaction_id = ?', whereArgs: [ids.first]);
    expect(toHex0x(MerkleEngine.merkleRoot(await db.logsFor(ids))), isNot(checkpoint.merkleRoot));
    // The frozen leaves still reproduce the signed root, so re-signing later still covers the original values.
    expect(toHex0x(MerkleEngine.rootFromLeaves((await db.pendingLeaves()).map((l) => fromHex0x(l.leafHash)).toList())),
        checkpoint.merkleRoot);
    expect(await db.orphanPendingLogs(), isEmpty);
  });
}
