import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../providers/water_provider.dart';
import '../models/user_settings.dart';
import '../models/water_intake.dart';
import '../services/sync_service.dart';
import '../widgets/scale_button.dart';
import 'architect_screen.dart';
import 'about_screen.dart';
import 'debug_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _selectedAmount = 0;
  int _selectedStatPeriod = 2; // 0: Day, 1: Month, 2: Year
  int _statDateOffset = 0;
  int? _hoverIndex;
  StreamSubscription? _accelerometerSubscription;
  double _tiltX = 0.0;
  double _tiltY = 0.0;
  FixedExtentScrollController? _rulerController;
  AnimationController? _waveController;
  AnimationController? _themeController;
  Offset _themeToggleOffset = Offset.zero;
  final GlobalKey _themeKey = GlobalKey();

  // Softer Dark Mode Theme (Consistent Dusty Midnight Palette)
  static const Color darkBg = Color(0xFF1B232A);
  static const Color darkCard = Color(0xFF242E38);
  static const Color darkHighlight = Color(0xFF78909C);
  static const Color darkAccent = Color(0xFF37474F);
  static const Color darkTextSecondary = Color(0xFF607D8B);

  // Light Mode Theme (Ultra-Soft Dusty Ocean Palette)
  static const Color lightBg = Color(0xFFDCE4E8);
  static const Color lightCard = Color(0xFFE5ECF0);
  static const Color lightHighlight = Color(0xFF608DA1);
  static const Color lightAccent = Color(0xFF8BA9B8);
  static const Color lightTextSecondary = Color(0xFF546E7A);

  @override
  void initState() {
    super.initState();
    _rulerController = FixedExtentScrollController(initialItem: 0);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _themeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    if (Platform.isAndroid) {
      _accelerometerSubscription =
          accelerometerEventStream().listen((AccelerometerEvent event) {
        setState(() {
          // Subtle tilt based on movement
          _tiltX = event.x * -0.05; // Adjust sensitivity
          _tiltY = event.y * 0.05;
        });
      });
    }

    // Initialize stats period from settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<WaterProvider>(context, listen: false);
      if (provider.settings != null) {
        setState(() {
          _selectedStatPeriod = provider.settings!.selectedStatPeriod;
        });
      }
    });
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _rulerController?.dispose();
    _waveController?.dispose();
    _themeController?.dispose();
    super.dispose();
  }

  void _syncRuler(int amount) {
    setState(() => _selectedAmount = amount);
    if (_rulerController != null && _rulerController!.hasClients) {
      _rulerController!.animateToItem(
        amount ~/ 10,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
    HapticFeedback.lightImpact();
  }

  void _showResetOptions(BuildContext context) {
    final waterProvider = Provider.of<WaterProvider>(context, listen: false);
    final isDark = waterProvider.settings?.isDarkMode ?? true;
    final cardColor = isDark ? darkCard : lightCard;
    final highlightColor = isDark ? darkHighlight : lightHighlight;
    final textPrimary =
        isDark ? const Color(0xFFCFD8DC) : const Color(0xFF455A64);
    final textSecondary = isDark ? darkTextSecondary : lightTextSecondary;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reset Options',
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
              const SizedBox(height: 8),
              Text(
                  'Select the scope of the reset. This action cannot be undone.',
                  style: TextStyle(color: textSecondary, fontSize: 14)),
              const SizedBox(height: 24),
              _buildResetTile(
                context,
                icon: Icons.today_rounded,
                title: "Reset Today's Data",
                subtitle:
                    "Clear all water logs for ${DateTime.now().toString().substring(0, 10)}",
                color: highlightColor,
                onTap: () {
                  waterProvider.resetToday();
                  _syncRuler(0);
                },
              ),
              const SizedBox(height: 12),
              _buildResetTile(
                context,
                icon: Icons.history_rounded,
                title: "Reset All History",
                subtitle: "Clear every water log ever recorded",
                color: Colors.orangeAccent,
                onTap: () => waterProvider.resetAllHistory(),
              ),
              const SizedBox(height: 12),
              _buildResetTile(
                context,
                icon: Icons.warning_amber_rounded,
                title: "Full Factory Reset",
                subtitle: "Clear all settings, cloud links, and history",
                color: Colors.redAccent,
                isCritical: true,
                onTap: () => waterProvider.resetFullApp(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResetTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isCritical = false,
  }) {
    final waterProvider = Provider.of<WaterProvider>(context, listen: false);
    final isDark = waterProvider.settings?.isDarkMode ?? true;
    final textPrimary =
        isDark ? const Color(0xFFCFD8DC) : const Color(0xFF455A64);
    final textSecondary = isDark ? darkTextSecondary : lightTextSecondary;

    return ScaleButton(
      onTap: () {
        Navigator.pop(context);
        _showConfirmationDialog(context, title, isCritical, onTap);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      style: TextStyle(color: textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context, String title,
      bool isCritical, VoidCallback onConfirm) {
    final waterProvider = Provider.of<WaterProvider>(context, listen: false);
    final isDark = waterProvider.settings?.isDarkMode ?? true;
    final cardColor = isDark ? darkCard : lightCard;
    final textPrimary =
        isDark ? const Color(0xFFCFD8DC) : const Color(0xFF455A64);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Are you sure?',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w900)),
        content: Text(
          'You are about to $title. This action is permanent and cannot be reversed.',
          style: TextStyle(color: textPrimary.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: textPrimary.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
              HapticFeedback.heavyImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$title Completed'),
                  backgroundColor:
                      isCritical ? Colors.redAccent : Colors.blueGrey,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isCritical ? Colors.redAccent : Colors.blueGrey,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirm Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final waterProvider = Provider.of<WaterProvider>(context);
    final isDark = waterProvider.settings?.isDarkMode ?? true;

    final bgColor = isDark ? darkBg : lightBg;
    final cardColor = isDark ? darkCard : lightCard;
    final highlightColor = isDark ? darkHighlight : lightHighlight;
    final accentColor = isDark ? darkAccent : lightAccent;
    final textSecondary = isDark ? darkTextSecondary : lightTextSecondary;
    final textPrimary =
        isDark ? const Color(0xFFCFD8DC) : const Color(0xFF455A64);

    if (waterProvider.settings == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: highlightColor),
              const SizedBox(height: 20),
              Text('Initializing HydroSync...',
                  style: TextStyle(color: textSecondary, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    final displayBgColor = (_themeController?.isAnimating ?? false)
        ? (isDark ? lightBg : darkBg)
        : bgColor;

    return Scaffold(
      backgroundColor: displayBgColor,
      extendBody: true,
      body: Stack(
        children: [
          if (_themeController != null)
            AnimatedBuilder(
              animation: _themeController!,
              builder: (context, child) {
                if (!_themeController!.isAnimating &&
                    !_themeController!.isCompleted) {
                  return const SizedBox.shrink();
                }
                return CustomPaint(
                  painter: CircularRevealPainter(
                    offset: _themeToggleOffset,
                    progress: _themeController!.value,
                    color: bgColor,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(waterProvider, textPrimary, cardColor, highlightColor),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeInOutCubic,
                    switchOutCurve: Curves.easeInOutCubic,
                    layoutBuilder:
                        (Widget? currentChild, List<Widget> previousChildren) {
                      return Stack(
                        alignment: Alignment.topCenter,
                        children: <Widget>[
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    child: _buildCurrentTab(
                        waterProvider,
                        isDark,
                        bgColor,
                        cardColor,
                        highlightColor,
                        accentColor,
                        textSecondary,
                        textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(waterProvider, isDark, cardColor,
          highlightColor, accentColor, textSecondary),
    );
  }

  Widget _buildHeader(WaterProvider waterProvider, Color textPrimary,
      Color cardColor, Color highlightColor) {
    final isDark = waterProvider.settings?.isDarkMode ?? true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('hydrosync',
              style: TextStyle(
                  color: textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1)),
          Row(
            children: [
              if (false && kDebugMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ScaleButton(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const DebugScreen())),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: cardColor, shape: BoxShape.circle),
                      child: Icon(Icons.bug_report,
                          color: highlightColor, size: 18),
                    ),
                  ),
                ),
              ScaleButton(
                onTap: () => _showResetOptions(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration:
                      BoxDecoration(color: cardColor, shape: BoxShape.circle),
                  child: Icon(Icons.refresh, color: textPrimary, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              ScaleButton(
                key: _themeKey,
                onTap: () {
                  final box = _themeKey.currentContext?.findRenderObject()
                      as RenderBox?;
                  if (box != null) {
                    _themeToggleOffset =
                        box.localToGlobal(box.size.center(Offset.zero));
                  }
                  waterProvider.toggleTheme();
                  _themeController?.forward(from: 0);
                  HapticFeedback.mediumImpact();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration:
                      BoxDecoration(color: cardColor, shape: BoxShape.circle),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return RotationTransition(
                        turns: Tween<double>(begin: 0.5, end: 1.0)
                            .animate(animation),
                        child: ScaleTransition(
                            scale: animation,
                            child: FadeTransition(
                                opacity: animation, child: child)),
                      );
                    },
                    child: Icon(
                        isDark ? Icons.dark_mode : Icons.wb_sunny_rounded,
                        key: ValueKey<bool>(isDark),
                        color: textPrimary,
                        size: 18),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab(
      WaterProvider waterProvider,
      bool isDark,
      Color bgColor,
      Color cardColor,
      Color highlightColor,
      Color accentColor,
      Color textSecondary,
      Color textPrimary) {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab(waterProvider, isDark, cardColor, highlightColor,
            accentColor, textSecondary, textPrimary,
            key: const ValueKey('home'));
      case 1:
        return _buildStatsTab(waterProvider, isDark, cardColor, highlightColor,
            accentColor, textSecondary, textPrimary,
            key: const ValueKey('stats'));
      case 2:
        return _buildSettingsTab(waterProvider, isDark, cardColor,
            highlightColor, accentColor, textSecondary, textPrimary,
            key: const ValueKey('settings'));
      default:
        return _buildHomeTab(waterProvider, isDark, cardColor, highlightColor,
            accentColor, textSecondary, textPrimary,
            key: const ValueKey('home'));
    }
  }

  Widget _buildHomeTab(
      WaterProvider waterProvider,
      bool isDark,
      Color cardColor,
      Color highlightColor,
      Color accentColor,
      Color textSecondary,
      Color textPrimary,
      {Key? key}) {
    const double outerR = 25;
    const double innerR = 5;

    return RepaintBoundary(
      child: Padding(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            _buildMainStatusCard(waterProvider, isDark, cardColor,
                highlightColor, accentColor, textSecondary, textPrimary),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                  child: _buildVolumeCard(
                                150,
                                '150',
                                'mL',
                                isDark,
                                cardColor,
                                highlightColor,
                                accentColor,
                                textSecondary,
                                textPrimary,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(outerR),
                                  topRight: Radius.circular(innerR),
                                  bottomLeft: Radius.circular(outerR),
                                  bottomRight: Radius.circular(innerR),
                                ),
                              )),
                              const SizedBox(width: 2),
                              Expanded(
                                  child: _buildVolumeCard(
                                200,
                                '200',
                                'mL',
                                isDark,
                                cardColor,
                                highlightColor,
                                accentColor,
                                textSecondary,
                                textPrimary,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(innerR),
                                  topRight: Radius.circular(outerR),
                                  bottomLeft: Radius.circular(innerR),
                                  bottomRight: Radius.circular(outerR),
                                ),
                              )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          flex: 3,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _buildVolumeCard(
                                        250,
                                        '250',
                                        'mL',
                                        isDark,
                                        cardColor,
                                        highlightColor,
                                        accentColor,
                                        textSecondary,
                                        textPrimary,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(outerR),
                                          topRight: Radius.circular(innerR),
                                          bottomLeft: Radius.circular(innerR),
                                          bottomRight: Radius.circular(innerR),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Expanded(
                                      flex: 3,
                                      child: _buildVolumeCard(
                                        500,
                                        '500',
                                        'mL',
                                        isDark,
                                        cardColor,
                                        highlightColor,
                                        accentColor,
                                        textSecondary,
                                        textPrimary,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(innerR),
                                          topRight: Radius.circular(innerR),
                                          bottomLeft: Radius.circular(outerR),
                                          bottomRight: Radius.circular(innerR),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                flex: 1,
                                child: _buildVolumeCard(
                                  1000,
                                  '1',
                                  'Litre',
                                  isDark,
                                  cardColor,
                                  highlightColor,
                                  accentColor,
                                  textSecondary,
                                  textPrimary,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(innerR),
                                    topRight: Radius.circular(outerR),
                                    bottomLeft: Radius.circular(innerR),
                                    bottomRight: Radius.circular(outerR),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildTallFineController(isDark, cardColor, highlightColor,
                      accentColor, textSecondary, textPrimary),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildMainStatusCard(
      WaterProvider waterProvider,
      bool isDark,
      Color cardColor,
      Color highlightColor,
      Color accentColor,
      Color textSecondary,
      Color textPrimary) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
          color: cardColor, borderRadius: BorderRadius.circular(25)),
      child: Stack(
        children: [
          Positioned(
              right: 30,
              top: 30,
              bottom: 30,
              child: _buildBottleIndicator(waterProvider.progressPercentage,
                  highlightColor, isDark, textPrimary)),
          Padding(
            padding: const EdgeInsets.all(35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  child: Text(
                    '${(waterProvider.progressPercentage * 100).toInt()}%',
                    style: TextStyle(
                        color: highlightColor,
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                        height: 1),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                      color: highlightColor,
                      borderRadius: BorderRadius.circular(15)),
                  child: Text('hydrosynced',
                      style: TextStyle(
                          color:
                              isDark ? const Color(0xFF141921) : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
                const SizedBox(height: 20),
                Text(
                    '${waterProvider.dailyTotal} / ${waterProvider.adjustedGoal} mL',
                    style: TextStyle(color: textSecondary, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTallFineController(
      bool isDark,
      Color cardColor,
      Color highlightColor,
      Color accentColor,
      Color textSecondary,
      Color textPrimary) {
    return Container(
      width: 70,
      child: Column(
        children: [
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: textPrimary.withOpacity(0.05))),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: textPrimary.withOpacity(0.02),
                      border: Border(
                          bottom:
                              BorderSide(color: textPrimary.withOpacity(0.05))),
                    ),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: [
                          TextSpan(
                              text: '${_selectedAmount}',
                              style: TextStyle(
                                  color: highlightColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900)),
                          TextSpan(
                              text: '\nmL',
                              style: TextStyle(
                                  color: highlightColor.withOpacity(0.5),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ExcludeSemantics(
                          child: ListWheelScrollView.useDelegate(
                            controller: _rulerController!,
                            itemExtent: 14,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              setState(() => _selectedAmount = index * 10);
                              HapticFeedback.selectionClick();
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              builder: (context, index) {
                                if (index < 0 || index > 100) return null;
                                bool is250 = (index * 10) % 250 == 0;
                                bool isMajor = index % 5 == 0;
                                return Center(
                                  child: Container(
                                    height: is250 ? 4 : 2,
                                    width: is250 ? 55 : (isMajor ? 40 : 20),
                                    decoration: BoxDecoration(
                                        color: is250
                                            ? (isDark
                                                ? const Color(0xFFE2E8F0)
                                                : highlightColor)
                                            : (isMajor
                                                ? textPrimary.withOpacity(0.24)
                                                : textPrimary.withOpacity(0.1)),
                                        borderRadius: BorderRadius.circular(2)),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: Center(
                            child: Container(
                              height: 3,
                              width: 50,
                              decoration: BoxDecoration(
                                  color: highlightColor,
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                        color: highlightColor.withOpacity(0.3),
                                        blurRadius: 10)
                                  ]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildRulerButton(Icons.keyboard_arrow_up, () {
            if (_selectedAmount < 1000) _syncRuler(_selectedAmount + 10);
          }, isDark, cardColor, textPrimary, isTop: true),
          const SizedBox(height: 2),
          _buildRulerButton(Icons.keyboard_arrow_down, () {
            if (_selectedAmount > 0) _syncRuler(_selectedAmount - 10);
          }, isDark, cardColor, textPrimary, isTop: false),
        ],
      ),
    );
  }

  Widget _buildRulerButton(IconData icon, VoidCallback onTap, bool isDark,
      Color cardColor, Color textPrimary,
      {required bool isTop}) {
    return ScaleButton(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        width: 70,
        height: 45,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(isTop ? 25 : 5),
            bottom: Radius.circular(isTop ? 5 : 25),
          ),
          border: Border.all(color: textPrimary.withOpacity(0.05)),
        ),
        child: Icon(icon, color: textPrimary.withOpacity(0.54), size: 24),
      ),
    );
  }

  Widget _buildBottleIndicator(
      double progress, Color highlightColor, bool isDark, Color textPrimary) {
    return LayoutBuilder(builder: (context, constraints) {
      final actualHeight = constraints.maxHeight;
      return Container(
        width: 45,
        height: actualHeight,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: 40,
              height: actualHeight,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.02),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                  bottom: Radius.circular(15),
                ),
                border: Border.all(
                  color: textPrimary.withOpacity(0.1),
                  width: 1.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Liquid Fill (Dynamic Surface Physics)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: DynamicLiquidPainter(
                        progress: progress,
                        tiltX: _tiltX,
                        color: highlightColor,
                      ),
                    ),
                  ),
                  // Permanent Glass Shine
                  Positioned(
                    top: 15,
                    left: 8,
                    child: Container(
                      width: 4,
                      height: 45,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(isDark ? 0.15 : 0.25),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Decorative String on Cap (With Wave Animation)
            Positioned(
              top: 8,
              right: 10,
              child: AnimatedBuilder(
                animation: _waveController!,
                builder: (context, child) {
                  return SizedBox(
                    width: 10,
                    height: 35,
                    child: CustomPaint(
                      painter: StringWavePainter(
                        animValue: _waveController!.value,
                        color: textPrimary.withOpacity(0.2),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Bottle Cap
            Positioned(
              top: 0,
              child: Container(
                width: 25,
                height: 8,
                decoration: BoxDecoration(
                  color: textPrimary.withOpacity(0.3),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    )
                  ],
                ),
              ),
            ),
            // Scale Marks on Glass
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                    8,
                    (i) => Container(
                          width: 10,
                          height: 1.5,
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.05),
                        )),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStatsTab(
      WaterProvider waterProvider,
      bool isDark,
      Color cardColor,
      Color highlightColor,
      Color accentColor,
      Color textSecondary,
      Color textPrimary,
      {Key? key}) {
    final aggregatedDataRaw = _getAggregatedDataRaw(waterProvider.intakes);
    final aggregatedDataNormalized = _normalize(aggregatedDataRaw);
    final debt = waterProvider.settings?.hydrationDebt ?? 0;

    return RepaintBoundary(
      child: SingleChildScrollView(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 180),
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                  color: cardColor, borderRadius: BorderRadius.circular(30)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HYDRATION DEBT',
                      style: TextStyle(
                          color: textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text('${debt} mL',
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900)),
                  Text('from previous days',
                      style: TextStyle(color: textSecondary, fontSize: 12)),
                  const SizedBox(height: 20),
                  ScaleButton(
                    onTap: () {
                      if (!waterProvider.settings!.isCatchingUp) {
                        waterProvider.catchUp();
                        HapticFeedback.mediumImpact();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                          color: waterProvider.settings!.isCatchingUp
                              ? highlightColor.withOpacity(0.2)
                              : accentColor,
                          borderRadius: BorderRadius.circular(30),
                          border: waterProvider.settings!.isCatchingUp
                              ? Border.all(
                                  color: highlightColor.withOpacity(0.3))
                              : null),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                                waterProvider.settings!.isCatchingUp
                                    ? Icons.check_circle
                                    : Icons.bolt,
                                color: waterProvider.settings!.isCatchingUp
                                    ? highlightColor
                                    : Colors.white,
                                size: 18),
                            const SizedBox(width: 10),
                            Text(
                                waterProvider.settings!.isCatchingUp
                                    ? 'Debt Integrated'
                                    : 'Catch Up',
                                style: TextStyle(
                                    color: waterProvider.settings!.isCatchingUp
                                        ? highlightColor
                                        : Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 350,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                  color: cardColor, borderRadius: BorderRadius.circular(30)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_hoverIndex != null)
                        Text(_getHoverLabel(aggregatedDataRaw[_hoverIndex!]),
                            style: TextStyle(
                                color: highlightColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                    ],
                  ),
                  const Spacer(),
                  LayoutBuilder(builder: (context, constraints) {
                    return GestureDetector(
                      onPanUpdate: (details) => _handleGraphInteraction(
                          details.localPosition.dx,
                          constraints.maxWidth,
                          aggregatedDataNormalized.length),
                      onTapDown: (details) => _handleGraphInteraction(
                          details.localPosition.dx,
                          constraints.maxWidth,
                          aggregatedDataNormalized.length),
                      onPanEnd: (_) => setState(() => _hoverIndex = null),
                      onTapUp: (_) => setState(() => _hoverIndex = null),
                      child: _waveController == null
                          ? const SizedBox()
                          : AnimatedBuilder(
                              animation: _waveController!,
                              builder: (context, child) {
                                return RepaintBoundary(
                                  child: SizedBox(
                                    height: 180,
                                    width: double.infinity,
                                    child: CustomPaint(
                                      painter: WaveChartPainter(
                                        accentColor: highlightColor,
                                        data: aggregatedDataNormalized,
                                        hoverIndex: _hoverIndex,
                                        animValue: _waveController!.value,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                    );
                  }),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ScaleButton(
                        onTap: () {
                          setState(() {
                            _statDateOffset--;
                            _hoverIndex = null;
                          });
                          HapticFeedback.lightImpact();
                        },
                        child: Icon(Icons.chevron_left, color: textSecondary),
                      ),
                      Text(_getStatPeriodLabel(),
                          style: TextStyle(
                              color: textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      ScaleButton(
                        onTap: _statDateOffset >= 0
                            ? null
                            : () {
                                setState(() {
                                  _statDateOffset++;
                                  _hoverIndex = null;
                                });
                                HapticFeedback.lightImpact();
                              },
                        child: Icon(Icons.chevron_right,
                            color: _statDateOffset >= 0
                                ? textSecondary.withOpacity(0.2)
                                : textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(minHeight: 90),
              child: Row(
                children: [
                  _statPeriodItem(0, 'Day', isDark, cardColor, highlightColor,
                      textSecondary, textPrimary),
                  const SizedBox(width: 8),
                  _statPeriodItem(1, 'Month', isDark, cardColor, highlightColor,
                      textSecondary, textPrimary),
                  const SizedBox(width: 8),
                  _statPeriodItem(2, 'Year', isDark, cardColor, highlightColor,
                      textSecondary, textPrimary),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _handleGraphInteraction(double dx, double width, int dataLength) {
    if (dataLength < 2) return;
    int index =
        (dx / width * (dataLength - 1)).round().clamp(0, dataLength - 1);
    if (index != _hoverIndex) {
      setState(() => _hoverIndex = index);
      HapticFeedback.selectionClick();
    }
  }

  String _getStatPeriodLabel() {
    final now = DateTime.now();
    if (_selectedStatPeriod == 0) {
      if (_statDateOffset == 0) return 'Today';
      if (_statDateOffset == -1) return 'Yesterday';
      final target = now.add(Duration(days: _statDateOffset));
      return '${target.day} ${_getMonthName(target.month)}';
    } else if (_selectedStatPeriod == 1) {
      final target = DateTime(now.year, now.month + _statDateOffset, 1);
      if (_statDateOffset == 0) return 'This Month';
      return '${_getMonthName(target.month)} ${target.year}';
    } else {
      final target = DateTime(now.year + _statDateOffset, 1, 1);
      if (_statDateOffset == 0) return 'This Year';
      return '${target.year}';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  String _getHoverLabel(double value) {
    String valText = value >= 1000
        ? '${(value / 1000).toStringAsFixed(1)}L'
        : '${value.toInt()}mL';
    if (_selectedStatPeriod == 0) return '${_hoverIndex}:00 • $valText';
    if (_selectedStatPeriod == 1) return 'Day ${_hoverIndex! + 1} • $valText';
    return '${_getMonthName(_hoverIndex! + 1)} • $valText';
  }

  List<double> _getAggregatedDataRaw(List<WaterIntake> intakes) {
    final baseNow = DateTime.now();
    if (_selectedStatPeriod == 0) {
      final target = baseNow.add(Duration(days: _statDateOffset));
      final List<double> hourly = List.filled(24, 0.0);
      for (var intake in intakes) {
        if (intake.timestamp.year == target.year &&
            intake.timestamp.month == target.month &&
            intake.timestamp.day == target.day) {
          hourly[intake.timestamp.hour] += intake.amount;
        }
      }
      return hourly;
    } else if (_selectedStatPeriod == 1) {
      final target = DateTime(baseNow.year, baseNow.month + _statDateOffset, 1);
      final List<double> daily = List.filled(31, 0.0); // Use 31 for safety
      for (var intake in intakes) {
        if (intake.timestamp.year == target.year &&
            intake.timestamp.month == target.month) {
          int dayIndex = intake.timestamp.day - 1;
          if (dayIndex < 31) daily[dayIndex] += intake.amount;
        }
      }
      return daily;
    } else {
      final targetYear = baseNow.year + _statDateOffset;
      final List<double> monthly = List.filled(12, 0.0);
      for (var intake in intakes) {
        if (intake.timestamp.year == targetYear) {
          monthly[intake.timestamp.month - 1] += intake.amount;
        }
      }
      return monthly;
    }
  }

  List<double> _normalize(List<double> data) {
    if (data.isEmpty) return [];
    double maxVal = data.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return data;
    return data.map((v) => v / maxVal).toList();
  }

  Widget _statPeriodItem(int index, String label, bool isDark, Color cardColor,
      Color highlightColor, Color textSecondary, Color textPrimary) {
    bool isSelected = _selectedStatPeriod == index;
    return Expanded(
      child: ScaleButton(
        onTap: () {
          setState(() {
            _selectedStatPeriod = index;
            _statDateOffset = 0; // Reset offset when switching view type
            _hoverIndex = null;
          });
          final waterProvider =
              Provider.of<WaterProvider>(context, listen: false);
          if (waterProvider.settings != null) {
            final s = waterProvider.settings!;
            s.selectedStatPeriod = index;
            // Silent update: No AI strategist trigger and NO cloud sync for UI layout changes
            waterProvider.updateSettings(s,
                refreshAi: false, syncToCloud: false);
          }
        },
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border:
                isSelected ? Border.all(color: highlightColor, width: 2) : null,
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: isSelected ? textPrimary : textSecondary,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTab(
      WaterProvider waterProvider,
      bool isDark,
      Color cardColor,
      Color highlightColor,
      Color accentColor,
      Color textSecondary,
      Color textPrimary,
      {Key? key}) {
    final settings = waterProvider.settings;

    return RepaintBoundary(
      child: SingleChildScrollView(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Profile & Customization', textSecondary),
            ScaleButton(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ArchitectScreen())),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: cardColor, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: highlightColor.withOpacity(0.1),
                              shape: BoxShape.circle),
                          child: Icon(Icons.tune_rounded,
                              color: highlightColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Personalizer',
                                  style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              Text('Customize biological profile',
                                  style: TextStyle(
                                      color: textSecondary, fontSize: 11)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            color: textSecondary, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _buildSectionHeader('AI Intelligence', textSecondary),
            ScaleButton(
              onTap: () {
                if (waterProvider.settings?.aiEngine == 'NVIDIA') {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text(
                        'AI is strategizing in background, this may take a moment.'),
                    backgroundColor: highlightColor,
                    behavior: SnackBarBehavior.floating,
                  ));
                  waterProvider.applyAiStrategy();
                } else {
                  _showAiArchitectLoading(
                      context, waterProvider, highlightColor, isDark);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: cardColor, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_awesome,
                                    color: highlightColor, size: 16),
                                const SizedBox(width: 6),
                                Text('AI TARGET',
                                    style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('${waterProvider.settings?.dailyGoal} mL',
                                style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                        ScaleButton(
                          onTap: () {
                            if (waterProvider.settings?.aiEngine == 'NVIDIA') {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: const Text(
                                    'AI is strategizing in background, this may take time.'),
                                backgroundColor: highlightColor,
                                behavior: SnackBarBehavior.floating,
                              ));
                              waterProvider.applyAiStrategy();
                            } else {
                              _showAiArchitectLoading(context, waterProvider,
                                  highlightColor, isDark);
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOutCubic,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                                color: highlightColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                      color: highlightColor.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4))
                                ]),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt,
                                    color: isDark
                                        ? const Color(0xFF141921)
                                        : Colors.white,
                                    size: 14),
                                const SizedBox(width: 4),
                                Text('Resync AI',
                                    style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFF141921)
                                            : Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (settings?.aiRationale != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: highlightColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: highlightColor.withOpacity(0.3))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: highlightColor, size: 16),
                        const SizedBox(width: 8),
                        Text('AI RATIONALE',
                            style: TextStyle(
                                color: highlightColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(settings!.aiRationale!,
                        style: TextStyle(
                            color: textPrimary, fontSize: 12, height: 1.3)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            ScaleButton(
              onTap: () async {
                final syncService = SyncService();
                if (syncService.currentUser == null) {
                  final user = await syncService.signInWithGoogle();
                  if (user != null) {
                    // 1. Restore from cloud first (catches new-device scenario)
                    final cloud = await syncService.restoreAll();
                    if (cloud?.settings != null) {
                      await Provider.of<WaterProvider>(context, listen: false)
                          .updateSettings(cloud!.settings!);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Profile restored from cloud.')));
                    } else {
                      // 2. Nothing in cloud yet — push current local state up
                      await syncService.backupSettings(settings!);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Profile backed up to cloud.')));
                    }
                    setState(() {});
                  }
                } else {
                  // Show confirmation before sign out
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: cardColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                      title: Text('Sign Out?',
                          style: TextStyle(
                              color: textPrimary, fontWeight: FontWeight.w900)),
                      content: Text(
                        'Are you sure you want to sign out? Your data will remain on this device, but it won\'t sync to the cloud until you sign back in.',
                        style: TextStyle(color: textPrimary.withOpacity(0.8)),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel',
                              style: TextStyle(
                                  color: textPrimary.withOpacity(0.5))),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await syncService.signOut();
                            Navigator.pop(context);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Signed out.')));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: cardColor, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: SyncService().currentUser?.photoURL != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                  SyncService().currentUser!.photoURL!,
                                  fit: BoxFit.cover))
                          : const Icon(Icons.cloud_sync,
                              color: Colors.red, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              SyncService().currentUser?.displayName ??
                                  'Google Sync',
                              style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                          Text(
                              SyncService().currentUser != null
                                  ? (SyncService().currentUser!.email ??
                                      'Signed in')
                                  : 'Sign in to backup',
                              style: TextStyle(
                                  color: textSecondary, fontSize: 10)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: textSecondary, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            ScaleButton(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const AboutScreen())),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: cardColor, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: highlightColor.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: Icon(Icons.info_outline_rounded,
                          color: highlightColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('About hydrosync',
                              style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                          Text('See app details',
                              style: TextStyle(
                                  color: textSecondary, fontSize: 10)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: textSecondary, size: 16),
                  ],
                ),
              ),
            ),
            if (false) ...[
              const SizedBox(height: 10),
              _buildSectionHeader('Debug & Validation', textSecondary),
              ScaleButton(
                onTap: () async {
                  await waterProvider.notificationService.testNotification();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text(
                        'Alarm scheduled! Locking your phone now is recommended for testing.'),
                    backgroundColor: highlightColor,
                    behavior: SnackBarBehavior.floating,
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.withOpacity(0.3))),
                  child: Row(
                    children: [
                      const Icon(Icons.bug_report,
                          color: Colors.orange, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Trigger Immersive Alarm',
                                style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                            const Text('Tests full-screen intent in 10 seconds',
                                style: TextStyle(
                                    color: Colors.orange, fontSize: 10)),
                          ],
                        ),
                      ),
                      const Icon(Icons.timer_outlined,
                          color: Colors.orange, size: 16),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showAiArchitectLoading(BuildContext context, WaterProvider provider,
      Color highlightColor, bool isDark) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Center(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.all(35),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF1E242E).withOpacity(0.8),
                          const Color(0xFF141921).withOpacity(0.9)
                        ]
                      : [
                          Colors.white.withOpacity(0.8),
                          const Color(0xFFDCF0FA).withOpacity(0.9)
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(35),
                border: Border.all(
                    color: highlightColor.withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: highlightColor.withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 5),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 60,
                    width: 60,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                            color: highlightColor, strokeWidth: 3),
                        Icon(Icons.auto_awesome,
                            color: highlightColor, size: 24),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  Text('Personalizing your plan...',
                      style: TextStyle(
                          color:
                              isDark ? Colors.white : const Color(0xFF1A3A4A),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 5),
                  Text(
                      'Consulting ${provider.settings?.aiEngine ?? "AI"} Strategist',
                      style: TextStyle(
                          color:
                              isDark ? Colors.white54 : const Color(0xFF6B8A9E),
                          fontSize: 9)),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await provider.applyAiStrategy();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('AI Plan Generated: ${provider.settings?.dailyGoal}mL'),
      backgroundColor: highlightColor,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _profileChip(
      IconData icon, String label, bool isDark, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textSecondary),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textSecondary) {
    return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Text(title,
            style: TextStyle(
                color: textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)));
  }

  Widget _buildBottomBar(WaterProvider provider, bool isDark, Color cardColor,
      Color highlightColor, Color accentColor, Color textSecondary) {
    bool isHome = _currentIndex == 0;

    return Container(
      height: 80,
      color: Colors.transparent,
      padding: const EdgeInsets.only(bottom: 20),
      child: Center(
        child: SizedBox(
          width: 220,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Navigation Icons Glide
              AnimatedPositioned(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOutQuart,
                left: isHome ? 0 : 40,
                child: Container(
                  height: 55,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(27.5),
                    border: Border.all(
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _navIcon(0, Icons.water_drop, isDark, accentColor,
                          textSecondary),
                      _navIcon(
                          1, Icons.tsunami, isDark, accentColor, textSecondary),
                      _navIcon(2, Icons.settings, isDark, accentColor,
                          textSecondary),
                    ],
                  ),
                ),
              ),
              // Add Button: Liquid Scale & Fade (Restored)
              Positioned(
                right: 0,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  switchInCurve: Curves.easeInOutQuart,
                  switchOutCurve: Curves.easeInOutQuart,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.5, end: 1.0)
                            .animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: isHome
                      ? ScaleButton(
                          onTap: () {
                            provider.addIntake(_selectedAmount);
                            HapticFeedback.heavyImpact();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOutCubic,
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                                color: highlightColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                      color: highlightColor.withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8))
                                ]),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                return RotationTransition(
                                  turns: Tween<double>(begin: 0.8, end: 1.0)
                                      .animate(CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOutBack)),
                                  child: ScaleTransition(
                                      scale: animation, child: child),
                                );
                              },
                              child: Icon(
                                Icons.add,
                                key: ValueKey(
                                    'add_btn_${provider.intakes.length}'),
                                color: isDark
                                    ? const Color(0xFF141921)
                                    : Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navIcon(int index, IconData icon, bool isDark, Color accentColor,
      Color textSecondary) {
    bool isSelected = _currentIndex == index;
    return ScaleButton(
      onTap: () {
        setState(() {
          _currentIndex = index;
          if (index == 1) {
            _statDateOffset = 0; // Reset offset whenever reopening Stats tab
          }
        });
        if (index == 0) {
          // Ensure ruler is synced after the home tab is rebuilt
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncRuler(_selectedAmount);
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: isSelected ? accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(100)),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return RotationTransition(
              turns: Tween<double>(begin: 0.8, end: 1.0).animate(
                  CurvedAnimation(
                      parent: animation, curve: Curves.easeOutBack)),
              child: ScaleTransition(scale: animation, child: child),
            );
          },
          child: Icon(icon,
              key: ValueKey('${index}_${isSelected}'),
              color: isSelected
                  ? (isDark ? const Color(0xFF141921) : Colors.white)
                  : textSecondary,
              size: 20),
        ),
      ),
    );
  }

  Widget _buildVolumeCard(
      int amount,
      String val,
      String unit,
      bool isDark,
      Color cardColor,
      Color highlightColor,
      Color accentColor,
      Color textSecondary,
      Color textPrimary,
      {BorderRadius? borderRadius}) {
    // Identify nearest lower and higher presets
    const List<int> presets = [150, 200, 250, 500, 1000];
    int? nearestLower;
    int? nearestHigher;

    for (int p in presets) {
      if (p <= _selectedAmount) nearestLower = p;
    }
    for (int p in presets) {
      if (p >= _selectedAmount) {
        nearestHigher = p;
        break;
      }
    }

    bool isRelevant = amount == nearestLower || amount == nearestHigher;

    // Continuous proximity calculation (0.0 to 1.0)
    double proximity = 0.0;
    if (isRelevant) {
      double diff = (amount - _selectedAmount).abs().toDouble();

      // Custom range: 150 & 200 are very sensitive (10mL), others are standard (150mL)
      double range = (amount == 150 || amount == 200) ? 35.0 : 150.0;

      proximity = (1.0 - (diff / range)).clamp(0.0, 1.0);
    }

    // Use easeInCubic for a more distinct transition between "nearby" and "locked"
    // This ensures that at 50% distance, the highlight is only ~12% intensity
    double adjustedProximity = Curves.easeInCubic.transform(proximity);

    // Calculate multi-stage luminosity and saturation boost
    HSLColor hslHighlight = HSLColor.fromColor(highlightColor);
    HSLColor hslBase = HSLColor.fromColor(cardColor);

    // Stage 1: Base Lerp
    Color stage1Color =
        Color.lerp(cardColor, highlightColor, adjustedProximity)!;

    // Stage 2: Brightness & Vibrancy Boost (Magnetic Glow)
    // As we get very close (> 0.7), we boost the lightness and saturation
    double boost =
        (adjustedProximity > 0.7) ? (adjustedProximity - 0.7) / 0.3 : 0.0;
    HSLColor boostedHsl = HSLColor.fromColor(stage1Color)
        .withLightness(
            (HSLColor.fromColor(stage1Color).lightness + (0.02 * boost))
                .clamp(0.0, 1.0))
        .withSaturation(
            (HSLColor.fromColor(stage1Color).saturation + (0.03 * boost))
                .clamp(0.0, 1.0));

    Color currentColor = boostedHsl.toColor();

    // Stage 3: Locked Glow (Exact Match)
    bool isExact = _selectedAmount == amount;
    if (isExact) {
      currentColor = HSLColor.fromColor(highlightColor)
          .withLightness((hslHighlight.lightness + (isDark ? 0.05 : -0.04))
              .clamp(0.0, 1.0))
          .withSaturation((hslHighlight.saturation + 0.03).clamp(0.0, 1.0))
          .toColor();
    }

    // Delay the text color transition (lerp) until we are very close (> 0.8 adjusted proximity)
    // This prevents "muddy" text at intermediate highlight levels
    double textThreshold =
        (adjustedProximity > 0.8) ? (adjustedProximity - 0.8) / 0.2 : 0.0;

    Color currentTextPrimary = Color.lerp(textPrimary,
        isDark ? const Color(0xFF141921) : Colors.white, textThreshold)!;

    Color currentTextSecondary = Color.lerp(
        textSecondary,
        isDark
            ? const Color(0xFF141921).withOpacity(0.5)
            : Colors.white.withOpacity(0.7),
        textThreshold)!;

    // High-granularity font weight mapping (Every 10mL should feel different)
    List<FontWeight> weightRamp = [
      FontWeight.w400, // 0.0 - 0.1
      FontWeight.w500, // 0.1 - 0.2
      FontWeight.w600, // 0.2 - 0.3
      FontWeight.w700, // 0.3 - 0.4 (Bold)
      FontWeight.w700, // 0.4 - 0.6
      FontWeight.w800, // 0.6 - 0.8
      FontWeight.w800, // 0.8 - 0.9
      FontWeight.w900, // 0.9 - 1.0
      FontWeight.w900, // Locked
    ];
    int weightIndex = (adjustedProximity * 7).floor().clamp(0, 7);
    FontWeight currentWeight =
        isExact ? FontWeight.w900 : weightRamp[weightIndex];

    // Multi-layered highlighting variations (Stability prioritized)
    double borderThickness = 0.0;

    return ScaleButton(
      onTap: () => _syncRuler(amount),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: currentColor,
          borderRadius: borderRadius ?? BorderRadius.circular(25),
          border: Border.all(
              color: (adjustedProximity > 0.01 && !isExact)
                  ? currentTextPrimary.withOpacity(0.2 * adjustedProximity)
                  : Colors.transparent,
              width: borderThickness),
          boxShadow: isExact
              ? [
                  BoxShadow(
                    color: highlightColor.withOpacity(0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  )
                ]
              : (adjustedProximity > 0.1
                  ? [
                      BoxShadow(
                        color:
                            highlightColor.withOpacity(0.3 * adjustedProximity),
                        blurRadius: 20 * adjustedProximity,
                        offset: Offset(0, 5 * adjustedProximity),
                      )
                    ]
                  : []),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(val,
                  style: TextStyle(
                      color: currentTextPrimary,
                      fontSize: 32,
                      letterSpacing:
                          isExact ? -2.0 : (adjustedProximity * -1.0),
                      fontWeight: currentWeight)),
              Text(unit,
                  style: TextStyle(
                      color: currentTextSecondary,
                      fontSize: 14,
                      fontWeight: isExact ? FontWeight.w900 : currentWeight)),
            ],
          ),
        ),
      ),
    );
  }
}

class WaveChartPainter extends CustomPainter {
  final Color accentColor;
  final List<double> data;
  final int? hoverIndex;
  final double animValue;
  WaveChartPainter(
      {required this.accentColor,
      required this.data,
      this.hoverIndex,
      required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double dx = size.width / (data.length - 1);
    final List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
      double x = i * dx;
      double oscillation = sin((animValue * 2 * pi) + (i * 0.5)) * 4;
      double y = size.height - (data[i] * size.height * 0.8) + oscillation;
      points.add(Offset(x, y));
    }

    final fillPath = Path();
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      fillPath.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx,
          controlPoint2.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withOpacity(0.3),
          accentColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    final strokePath = Path();
    strokePath.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      strokePath.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx,
          controlPoint2.dy, p1.dx, p1.dy);
    }

    final strokePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(strokePath, strokePaint);

    if (hoverIndex != null && hoverIndex! < points.length) {
      final x = points[hoverIndex!].dx;
      final y = points[hoverIndex!].dy;

      final linePaint = Paint()
        ..color = (strokePaint.color).withOpacity(0.1)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);

      final pulsePaint = Paint()
        ..color = const Color(0xFFFF7E5F).withOpacity(0.3);
      canvas.drawCircle(Offset(x, y), 12, pulsePaint);

      final dotPaint = Paint()
        ..color = const Color(0xFFFF7E5F)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 6, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveChartPainter oldDelegate) => true;
}

class CircularRevealPainter extends CustomPainter {
  final Offset offset;
  final double progress;
  final Color color;

  CircularRevealPainter(
      {required this.offset, required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final maxRadius = sqrt(size.width * size.width + size.height * size.height);
    final radius = maxRadius * progress;

    final paint = Paint()..color = color;
    canvas.drawCircle(offset, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CircularRevealPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.offset != offset ||
        oldDelegate.color != color;
  }
}

class StringWavePainter extends CustomPainter {
  final double animValue;
  final Color color;

  StringWavePainter({required this.animValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    // Start at the top-right corner of our SizedBox (the attachment point)
    path.moveTo(size.width, 0);

    for (double i = 0; i <= size.height; i++) {
      // Create a wave that increases in amplitude as it goes down
      // Use sin wave driven by animValue
      double x =
          size.width + sin((animValue * 2 * pi) + (i * 0.15)) * (i * 0.08);
      path.lineTo(x, i);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant StringWavePainter oldDelegate) {
    return oldDelegate.animValue != animValue || oldDelegate.color != color;
  }
}

class DynamicLiquidPainter extends CustomPainter {
  final double progress;
  final double tiltX;
  final Color color;

  DynamicLiquidPainter({
    required this.progress,
    required this.tiltX,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.8),
          color,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final height = size.height * progress.clamp(0.0, 1.0);
    final yBase = size.height - height;

    // Calculate tilt displacement
    // max tilt offset is half the width
    final tiltOffset =
        (tiltX * size.width * 0.5).clamp(-size.width * 0.4, size.width * 0.4);

    // Points for the liquid polygon
    // Bottom stays flat
    path.moveTo(0, size.height);
    path.lineTo(size.width, size.height);

    // Top surface tilts
    path.lineTo(size.width, yBase - tiltOffset);
    path.lineTo(0, yBase + tiltOffset);

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DynamicLiquidPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.tiltX != tiltX ||
        oldDelegate.color != color;
  }
}
