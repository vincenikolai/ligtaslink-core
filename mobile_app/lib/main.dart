import 'package:flutter/material.dart';
import 'screens/home_scan_screen.dart';

const kOrange = Color(0xFFE94B0C);
const kOrangeDark = Color(0xFFD83E05);
const kInk = Color(0xFF171717);
const kCanvas = Color(0xFFFFF9F7);

void main() => runApp(const LigtasLinkApp());

class LigtasLinkApp extends StatelessWidget {
  const LigtasLinkApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'LigtasLink',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: kCanvas,
          colorScheme: ColorScheme.fromSeed(seedColor: kOrange),
          fontFamily: 'Arial',
          appBarTheme: const AppBarTheme(
            backgroundColor: kOrange,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
          ),
        ),
        home: const HomeScanScreen(),
      );
}
