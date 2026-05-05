import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../widgets/scale_button.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = '${info.version} (${info.buildNumber})';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1B232A) : const Color(0xFFDCE4E8);
    final cardColor =
        isDark ? const Color(0xFF242E38) : const Color(0xFFE5ECF0);
    final highlightColor =
        isDark ? const Color(0xFF78909C) : const Color(0xFF608DA1);
    final textPrimary =
        isDark ? const Color(0xFFCFD8DC) : const Color(0xFF455A64);
    final textSecondary =
        isDark ? const Color(0xFF607D8B) : const Color(0xFF546E7A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: textPrimary, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: highlightColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(Icons.water_drop_rounded,
                  color: highlightColor, size: 40),
            ),
            const SizedBox(height: 20),
            Text('HydroSync',
                style: TextStyle(
                    color: textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1)),
            Text('Version $_appVersion',
                style: TextStyle(color: textSecondary, fontSize: 11)),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: cardColor, borderRadius: BorderRadius.circular(25)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HydroSync is your biological strategist, leveraging high-density AI logic to synchronize your hydration with environmental shifts. We optimize performance through predictive scheduling and intelligent, immersive alerts.',
                    style: TextStyle(
                        color: textPrimary.withOpacity(0.8),
                        fontSize: 13,
                        height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DEVELOPER',
                              style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5)),
                          Text('rakinthegreat',
                              style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      ScaleButton(
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('github.com/rakinthegreat'))),
                        child: Icon(Icons.code_rounded,
                            color: highlightColor, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text('© 2026 Rakin Talukder',
                style: TextStyle(
                    color: textSecondary.withOpacity(0.5),
                    fontSize: 9,
                    letterSpacing: 1)),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
