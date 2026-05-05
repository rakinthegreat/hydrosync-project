import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/scale_button.dart';
import '../providers/water_provider.dart';
import '../models/user_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _goal;
  late TimeOfDay _waking;
  late TimeOfDay _sleeping;

  @override
  void initState() {
    super.initState();
    final settings = context.read<WaterProvider>().settings;
    _goal = settings?.dailyGoal ?? 2500;
    _waking = settings?.wakingTime ?? const TimeOfDay(hour: 7, minute: 0);
    _sleeping = settings?.sleepingTime ?? const TimeOfDay(hour: 22, minute: 0);
  }

  @override
  Widget build(BuildContext context) {
    final waterProvider = Provider.of<WaterProvider>(context);
    final isDark = waterProvider.settings?.isDarkMode ?? true;

    final bgColor = isDark ? const Color(0xFF1B232A) : const Color(0xFFDCE4E8);
    final cardColor = isDark ? const Color(0xFF242E38) : const Color(0xFFE5ECF0);
    final highlightColor = isDark ? const Color(0xFF78909C) : const Color(0xFF608DA1);
    final textPrimary = isDark ? const Color(0xFFCFD8DC) : const Color(0xFF455A64);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 150,
                pinned: true,
                backgroundColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text('Customizations', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [highlightColor.withOpacity(0.2), Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildGlassSection('Daily Targets', [
                      _buildSettingsItem(
                        'Daily Goal',
                        '$_goal mL',
                        Icons.radar,
                        () async {
                          final newGoal = await _showIntDialog('Set Daily Goal (mL)', _goal);
                          if (newGoal != null) setState(() => _goal = newGoal);
                        },
                        highlightColor,
                        textPrimary,
                      ),
                    ], highlightColor, isDark),
                    const SizedBox(height: 20),
                    _buildGlassSection('Active Schedule', [
                      _buildSettingsItem(
                        'Waking Time',
                        _waking.format(context),
                        Icons.wb_sunny_outlined,
                        () => _showCustomTimePicker('Waking Time', _waking, (time) => setState(() => _waking = time)),
                        highlightColor,
                        textPrimary,
                      ),
                      Divider(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                      _buildSettingsItem(
                        'Sleeping Time',
                        _sleeping.format(context),
                        Icons.nights_stay_outlined,
                        () => _showCustomTimePicker('Sleeping Time', _sleeping, (time) => setState(() => _sleeping = time)),
                        highlightColor,
                        textPrimary,
                      ),
                    ], highlightColor, isDark),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: highlightColor,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final provider = context.read<WaterProvider>();
                        provider.updateSettings(UserSettings(
                          dailyGoal: _goal,
                          wakingTime: _waking,
                          sleepingTime: _sleeping,
                          lastResetDate: provider.settings!.lastResetDate,
                          hydrationDebt: provider.settings!.hydrationDebt,
                        ));
                        Navigator.pop(context);
                      },
                      child: const Text('Save Customizations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassSection(String title, List<Widget> children, Color highlightColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: highlightColor.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
              ),
              child: Column(children: children),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(String title, String value, IconData icon, VoidCallback onTap, Color highlightColor, Color textColor) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: highlightColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: highlightColor),
      ),
      title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
      subtitle: Text(value, style: TextStyle(color: textColor.withOpacity(0.5))),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: textColor.withOpacity(0.2)),
      onTap: onTap,
    );
  }

  Future<int?> _showIntDialog(String title, int initialValue) {
    final controller = TextEditingController(text: initialValue.toString());
    return showDialog<int>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1D1E33),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
            TextButton(
              onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
              child: const Text('Save', style: TextStyle(color: Color(0xFF00D2FF))),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomTimePicker(String label, TimeOfDay initialTime, Function(TimeOfDay) onTimeChanged) {
    int hour = initialTime.hourOfPeriod == 0 ? 12 : initialTime.hourOfPeriod;
    int minute = initialTime.minute;
    bool isAm = initialTime.period == DayPeriod.am;

    final hourController = FixedExtentScrollController(initialItem: hour - 1);
    final minuteController = FixedExtentScrollController(initialItem: minute);

    final highlightColor = const Color(0xFF00D2FF);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1D1E33),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 30, right: 30, top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 30
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1D1E33),
              borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: highlightColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  const SizedBox(height: 30),
                  
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Unified Glowing Focus Card
                      Container(
                        height: 65,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: highlightColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: highlightColor.withOpacity(0.2), width: 1.5),
                          boxShadow: [
                            BoxShadow(color: highlightColor.withOpacity(0.05), blurRadius: 20, spreadRadius: 2)
                          ],
                        ),
                      ),
                      
                      Container(
                        height: 200,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 10),
                            // Hours Wheel
                            Expanded(
                              child: ListWheelScrollView.useDelegate(
                                controller: hourController,
                                itemExtent: 55,
                                diameterRatio: 1.2,
                                perspective: 0.008,
                                physics: const FixedExtentScrollPhysics(),
                                onSelectedItemChanged: (index) {
                                  hour = index + 1;
                                  HapticFeedback.selectionClick();
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  builder: (context, index) => Center(
                                    child: Text('${index + 1}', 
                                      style: const TextStyle(
                                        color: Colors.white, 
                                        fontSize: 28, 
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1,
                                      )),
                                  ),
                                  childCount: 12,
                                ),
                              ),
                            ),
                            
                            // Subtle Separator
                            Text(':', style: TextStyle(color: highlightColor.withOpacity(0.5), fontSize: 24, fontWeight: FontWeight.bold)),
                            
                            // Minutes Wheel
                            Expanded(
                              child: ListWheelScrollView.useDelegate(
                                controller: minuteController,
                                itemExtent: 55,
                                diameterRatio: 1.2,
                                perspective: 0.008,
                                physics: const FixedExtentScrollPhysics(),
                                onSelectedItemChanged: (index) {
                                  minute = index;
                                  HapticFeedback.selectionClick();
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  builder: (context, index) => Center(
                                    child: Text(index.toString().padLeft(2, '0'), 
                                      style: const TextStyle(
                                        color: Colors.white, 
                                        fontSize: 28, 
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1,
                                      )),
                                  ),
                                  childCount: 60,
                                ),
                              ),
                            ),
                            
                            // Animated AM/PM Selector
                            _amPmSelector(isAm, (val) => setModalState(() => isAm = val), highlightColor),
                            const SizedBox(width: 5),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Gorgeous Action Button
                  ScaleButton(
                    onTap: () {
                      int finalHour = hour % 12;
                      if (!isAm) finalHour += 12;
                      onTimeChanged(TimeOfDay(hour: finalHour, minute: minute));
                      Navigator.pop(context);
                      HapticFeedback.heavyImpact();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [highlightColor, highlightColor.withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: highlightColor.withOpacity(0.4), 
                            blurRadius: 20, 
                            offset: const Offset(0, 8),
                            spreadRadius: -2,
                          )
                        ],
                      ),
                      child: const Center(
                        child: Text('Confirm Schedule', 
                          style: TextStyle(
                            color: Colors.black, 
                            fontWeight: FontWeight.w900, 
                            fontSize: 16,
                            letterSpacing: 0.5,
                          )),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _amPmSelector(bool isAm, Function(bool) onChanged, Color highlightColor) {
    return Container(
      width: 100,
      height: 45,
      margin: const EdgeInsets.only(right: 10, left: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Stack(
        children: [
          // Sliding Background
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            alignment: isAm ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: 50,
              height: 45,
              decoration: BoxDecoration(
                color: highlightColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: highlightColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
            ),
          ),
          // Clickable Areas
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (!isAm) {
                      onChanged(true);
                      HapticFeedback.mediumImpact();
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: const Text('AM', 
                      style: TextStyle(
                        color: Colors.black, // Active text is black on light blue highlight
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1,
                      )),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (isAm) {
                      onChanged(false);
                      HapticFeedback.mediumImpact();
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: const Text('PM', 
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1,
                      )),
                  ),
                ),
              ),
            ],
          ),
          
          // Color overlays for text (to handle inactive state colors)
          IgnorePointer(
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isAm ? 0 : 1,
                      child: const Text('AM', 
                        style: TextStyle(
                          color: Colors.white24,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1,
                        )),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: !isAm ? 0 : 1,
                      child: const Text('PM', 
                        style: TextStyle(
                          color: Colors.white24,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1,
                        )),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
