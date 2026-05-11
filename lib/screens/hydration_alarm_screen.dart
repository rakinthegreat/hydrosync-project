import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/water_provider.dart';
import '../widgets/scale_button.dart';
import 'home_screen.dart';

class HydrationAlarmScreen extends StatefulWidget {
  final int? id;
  final int amount;
  final String note;
  final DateTime? scheduledAt;

  const HydrationAlarmScreen({
    super.key,
    this.id,
    required this.amount,
    this.note = "Time to hydrate!",
    this.scheduledAt,
  });

  @override
  State<HydrationAlarmScreen> createState() => _HydrationAlarmScreenState();
}

class _HydrationAlarmScreenState extends State<HydrationAlarmScreen>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _pulseController;
  DateTime? _previousNotificationTime;

  @override
  void initState() {
    super.initState();
    _loadPreviousNotificationTime();
    _saveCurrentNotificationTime();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    HapticFeedback.vibrate();
 
    // Surgically clear this specific notification from the tray
    if (widget.id != null) {
      final waterProvider = Provider.of<WaterProvider>(context, listen: false);
      waterProvider.notificationService.cancelNotification(widget.id!);
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadPreviousNotificationTime() async {
    final time = await waterProvider.storage.getLastNotificationTime();
    if (mounted) {
      setState(() {
        _previousNotificationTime = time;
      });
    }
  }

  Future<void> _saveCurrentNotificationTime() async {
    if (widget.scheduledAt != null) {
      await waterProvider.storage.saveLastNotificationTime(widget.scheduledAt!);
    } else {
      await waterProvider.storage.saveLastNotificationTime(DateTime.now());
    }
  }

  WaterProvider get waterProvider =>
      Provider.of<WaterProvider>(context, listen: false);

  @override
  Widget build(BuildContext context) {
    final waterProvider = Provider.of<WaterProvider>(context, listen: false);
    final isDark = waterProvider.settings?.isDarkMode ?? true;

    // Calculate time since last activity (drink OR previous notification)
    DateTime? lastActivityTime;

    // 1. Check last drink
    if (waterProvider.intakes.isNotEmpty) {
      lastActivityTime = waterProvider.intakes.last.timestamp;
    }

    // 2. Check last notification (from state)
    if (_previousNotificationTime != null) {
      if (lastActivityTime == null || _previousNotificationTime!.isAfter(lastActivityTime)) {
        lastActivityTime = _previousNotificationTime;
      }
    }

    String timeSinceText = "your last activity";
    if (lastActivityTime != null) {
      timeSinceText = DateFormat('h:mm a').format(lastActivityTime);
    }

    // Theme Colors
    final bgColor = isDark ? const Color(0xFF141921) : const Color(0xFFDCF0FA);
    final highlightColor =
        isDark ? const Color(0xFF78909C) : const Color(0xFF608DA1);
    final accentColor =
        isDark ? const Color(0xFF37474F) : const Color(0xFF8BA9B8);
    final textPrimary =
        isDark ? const Color(0xFFCFD8DC) : const Color(0xFF455A64);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 1. Animated Liquid Background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return CustomPaint(
                  painter: LiquidWavePainter(
                    animationValue: _waveController.value,
                    color: highlightColor.withOpacity(0.15),
                  ),
                );
              },
            ),
          ),

          // 2. Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // Pulse Glow behind the bottle/amount
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ScaleTransition(
                        scale: Tween<double>(begin: 1.0, end: 1.2).animate(
                          CurvedAnimation(
                              parent: _pulseController,
                              curve: Curves.easeInOut),
                        ),
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: highlightColor.withOpacity(0.2),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            '${widget.amount}',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 100,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -5,
                            ),
                          ),
                          Text(
                            'mL',
                            style: TextStyle(
                              color: textPrimary.withOpacity(0.5),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Glassmorphism Card for the note
                  ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.05),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: (isDark ? Colors.white : Colors.black)
                                .withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Did you drink ${widget.amount}mL since logging at $timeSinceText?\nIf not, drink now.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Divider(color: textPrimary.withOpacity(0.1)),
                            const SizedBox(height: 15),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome,
                                    color: highlightColor, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.note,
                                    style: TextStyle(
                                      color: textPrimary.withOpacity(0.6),
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Quick Log Options
                  Column(
                    children: [
                      Text(
                        'OR LOG SMALLER AMOUNT',
                        style: TextStyle(
                          color: textPrimary.withOpacity(0.3),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          ...[100, 150, 200].map((amt) {
                            return ScaleButton(
                              onTap: () async {
                                waterProvider.addIntake(amt);
                                HapticFeedback.mediumImpact();
                                // Close the app/background it after logging
                                await Future.delayed(
                                    const Duration(milliseconds: 200));
                                SystemNavigator.pop();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color:
                                        (isDark ? Colors.white : Colors.black)
                                            .withOpacity(0.1),
                                  ),
                                ),
                                child: Text(
                                  '${amt}mL',
                                  style: TextStyle(
                                    color: textPrimary.withOpacity(0.7),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                          ScaleButton(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              // Open the main app
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const HomeScreen()),
                                (route) => false,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.05),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withOpacity(0.1),
                                ),
                              ),
                              child: Text(
                                'Other',
                                style: TextStyle(
                                  color: highlightColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Action Buttons
                  Column(
                    children: [
                      ScaleButton(
                        onTap: () async {
                          waterProvider.addIntake(widget.amount);
                          HapticFeedback.heavyImpact();
                          // Close the app/background it after logging
                          await Future.delayed(
                              const Duration(milliseconds: 200));
                          SystemNavigator.pop();
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [highlightColor, accentColor],
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: highlightColor.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'DRANK',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () async {
                          waterProvider.notificationService
                              .snooze(widget.amount, widget.note, waterProvider.settings!);
                          HapticFeedback.mediumImpact();
                          // Background app after snoozing
                          await Future.delayed(
                              const Duration(milliseconds: 200));
                          SystemNavigator.pop();
                        },
                        child: Text(
                          'SNOOZE (10 MIN)',
                          style: TextStyle(
                            color: textPrimary.withOpacity(0.4),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LiquidWavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  LiquidWavePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();

    final yBase = size.height * 0.75;

    path.moveTo(0, size.height);
    path.lineTo(0, yBase);

    for (double x = 0; x <= size.width; x++) {
      double y = yBase + sin((animationValue * 2 * pi) + (x * 0.01)) * 15;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Secondary wave
    final paint2 = Paint()..color = color.withOpacity(0.1);
    final path2 = Path();
    path2.moveTo(0, size.height);
    path2.lineTo(0, yBase + 10);
    for (double x = 0; x <= size.width; x++) {
      double y = yBase + 10 + cos((animationValue * 2 * pi) + (x * 0.015)) * 10;
      path2.lineTo(x, y);
    }
    path2.lineTo(size.width, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
