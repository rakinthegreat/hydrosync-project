import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../providers/water_provider.dart';
import '../models/user_settings.dart';
import '../services/weather_service.dart';
import '../widgets/scale_button.dart';
import '../services/sync_service.dart';

class ArchitectScreen extends StatefulWidget {
  const ArchitectScreen({super.key});

  @override
  State<ArchitectScreen> createState() => _ArchitectScreenState();
}

class _ArchitectScreenState extends State<ArchitectScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Local Temp State
  late int tempAge;
  late double tempHeight;
  late double tempWeight;
  late String tempSex;
  late int tempFreq;
  late String tempIntense;
  late List<String> tempSports;
  late bool tempCycle;
  late List<DateTime> tempPeriods;
  late String tempProfession;
  late bool tempActiveWeekends;
  late String tempCustomNotes;
  late List<String> tempChronic;
  late List<String> tempTemp;
  late double tempT;
  late double tempH;
  late bool tempAutoWeather;
  late String tempCaf;
  late String tempAlc;
  late String tempSalt;
  late bool tempWeightMetric;
  late bool tempHeightMetric;
  late String tempEngine;
  late TimeOfDay tempWaking;
  late TimeOfDay tempSleeping;
  late TimeOfDay tempWorkStart;
  late TimeOfDay tempWorkEnd;
  late bool tempSound;
  late bool tempInsistent;
  bool _isSyncingWeather = false;

  // Scroll Controllers for multi-selectors
  final ScrollController _professionScroll = ScrollController();
  final ScrollController _sportsScroll = ScrollController();
  final ScrollController _chronicScroll = ScrollController();
  final ScrollController _tempScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    final s = Provider.of<WaterProvider>(context, listen: false).settings!;
    tempAge = s.age;
    tempHeight = s.height;
    tempWeight = s.weight;
    tempSex = s.sex;
    tempFreq = s.exerciseFrequency;
    tempIntense = s.exerciseIntensity;
    tempSports = List.from(s.sports);
    tempCycle = s.isTrackingCycle;
    tempPeriods = List.from(s.pastPeriods);
    tempProfession = s.profession;
    tempActiveWeekends = s.activeWeekends;
    tempCustomNotes = s.customNotes;
    tempChronic = List.from(s.chronicConditions);
    tempTemp = List.from(s.temporaryIllnesses);
    tempT = s.temperature;
    tempH = s.humidity;
    tempAutoWeather = s.autoWeather;
    tempCaf = s.caffeineLevel;
    tempAlc = s.alcoholLevel;
    tempSalt = s.saltIntake;
    tempWeightMetric = s.isWeightMetric;
    tempHeightMetric = s.isHeightMetric;
    tempEngine = s.aiEngine;
    tempWaking = s.wakingTime;
    tempSleeping = s.sleepingTime;
    tempWorkStart = s.workStartTime;
    tempWorkEnd = s.workEndTime;
    tempSound = s.enableAlarmSound;
    tempInsistent = s.insistentAlarm;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _professionScroll.dispose();
    _sportsScroll.dispose();
    _chronicScroll.dispose();
    _tempScroll.dispose();
    super.dispose();
  }

  void _syncWeather() async {
    if (!mounted) return;
    setState(() => _isSyncingWeather = true);
    final result = await WeatherService().fetchWeather();
    if (!mounted) return;
    setState(() => _isSyncingWeather = false);

    if (result != null) {
      setState(() {
        tempT = result['temperature'];
        tempH = result['humidity'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Synced with ${result['city']} trend!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to sync weather data')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final waterProvider = Provider.of<WaterProvider>(context);
    final isDark = waterProvider.settings?.isDarkMode ?? true;

    final bgColor = isDark ? const Color(0xFF1B232A) : const Color(0xFFDCE4E8);
    final cardColor =
        isDark ? const Color(0xFF242E38) : const Color(0xFFE5ECF0);
    final highlightColor =
        isDark ? const Color(0xFF78909C) : const Color(0xFF608DA1);
    final textSecondary =
        isDark ? const Color(0xFF607D8B) : const Color(0xFF546E7A);
    final textPrimary =
        isDark ? const Color(0xFFCFD8DC) : const Color(0xFF455A64);
    final accentColor =
        isDark ? const Color(0xFF37474F) : const Color(0xFF8BA9B8);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Personalizer',
            style: TextStyle(
                color: textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 55,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(27.5),
                border: Border.all(
                    color: (isDark ? Colors.white : Colors.black)
                        .withOpacity(0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navIcon(0, Icons.person_outline, isDark, accentColor,
                      highlightColor, textSecondary),
                  _navIcon(1, Icons.fitness_center, isDark, accentColor,
                      highlightColor, textSecondary),
                  _navIcon(2, Icons.medical_services_outlined, isDark,
                      accentColor, highlightColor, textSecondary),
                  _navIcon(3, Icons.eco_outlined, isDark, accentColor,
                      highlightColor, textSecondary),
                  _navIcon(4, Icons.access_time, isDark, accentColor,
                      highlightColor, textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // IDENTITY
                _buildTabWrapper([
                  Row(
                    children: [
                      Expanded(
                          child: _tactileValueButton(
                              'Age',
                              tempAge,
                              10,
                              100,
                              'yrs',
                              (v) => setState(() => tempAge = v),
                              highlightColor,
                              textPrimary,
                              textSecondary,
                              isDark)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _tactileSexButton(
                              tempSex,
                              (v) => setState(() => tempSex = v),
                              highlightColor,
                              textPrimary,
                              textSecondary,
                              isDark)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: _tactileValueButton(
                              'Weight',
                              tempWeight.toInt(),
                              30,
                              200,
                              tempWeightMetric ? 'kg' : 'lb',
                              (v) => setState(() => tempWeight = v.toDouble()),
                              highlightColor,
                              textPrimary,
                              textSecondary,
                              isDark,
                              showUnitToggle: true,
                              onUnitToggle: () => setState(() {
                                    if (tempWeightMetric) {
                                      tempWeight =
                                          (tempWeight * 2.20462); // kg to lb
                                    } else {
                                      tempWeight =
                                          (tempWeight / 2.20462); // lb to kg
                                    }
                                    tempWeightMetric = !tempWeightMetric;
                                  }))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _tactileValueButton(
                              'Height',
                              tempHeight.toInt(),
                              36,
                              100,
                              tempHeightMetric ? 'cm' : 'ft',
                              (v) => setState(() => tempHeight = v.toDouble()),
                              highlightColor,
                              textPrimary,
                              textSecondary,
                              isDark,
                              showUnitToggle: true,
                              onUnitToggle: () => setState(() {
                                    if (tempHeightMetric) {
                                      tempHeight =
                                          (tempHeight / 2.54); // cm to in
                                    } else {
                                      tempHeight =
                                          (tempHeight * 2.54); // in to cm
                                    }
                                    tempHeightMetric = !tempHeightMetric;
                                  }))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _innerCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PROFESSION',
                              style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2)),
                          const SizedBox(height: 8),
                          _multiChipSelector([
                            'Student',
                            'Office Worker',
                            'Active',
                            'Field Work',
                            'Athlete',
                            'Other'
                          ], [
                            [
                              'Student',
                              'Office Worker',
                              'Active',
                              'Field Work',
                              'Athlete'
                            ].contains(tempProfession)
                                ? tempProfession
                                : 'Other'
                          ], (v) {
                            if (v.isNotEmpty)
                              setState(() => tempProfession = v.last);
                          }, highlightColor, textSecondary, isDark,
                              _professionScroll),
                          if (![
                                'Student',
                                'Office Worker',
                                'Active',
                                'Field Work',
                                'Athlete'
                              ].contains(tempProfession) ||
                              tempProfession == 'Other') ...[
                            const SizedBox(height: 8),
                            _multilineTextField(
                                'CUSTOM',
                                tempProfession == 'Other' ? '' : tempProfession,
                                (v) => setState(() => tempProfession = v),
                                textPrimary,
                                textSecondary,
                                isDark,
                                lines: 1),
                          ],
                        ],
                      ),
                      isDark),
                ], isDark),

                // FITNESS
                _buildTabWrapper([
                  _tactileValueButton(
                      'Sessions / Week',
                      tempFreq,
                      0,
                      14,
                      'workouts',
                      (v) => setState(() => tempFreq = v),
                      highlightColor,
                      textPrimary,
                      textSecondary,
                      isDark),
                  const SizedBox(height: 8),
                  _innerCard(
                      _toggleGroup(
                          'INTENSITY',
                          tempIntense,
                          ['Low', 'Moderate', 'High'],
                          (v) => setState(() => tempIntense = v),
                          highlightColor,
                          textSecondary,
                          isDark),
                      isDark),
                  const SizedBox(height: 8),
                  _innerCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SPORTS',
                              style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2)),
                          const SizedBox(height: 8),
                          _multiChipSelector([
                            'Gym',
                            'Running',
                            'Swimming',
                            'Cycling',
                            'Yoga',
                            'Combat',
                            'Football',
                            'Tennis',
                            ...tempSports.where((s) => ![
                                  'Gym',
                                  'Running',
                                  'Swimming',
                                  'Cycling',
                                  'Yoga',
                                  'Combat',
                                  'Football',
                                  'Tennis'
                                ].contains(s))
                          ],
                              tempSports,
                              (v) => setState(() => tempSports = v),
                              highlightColor,
                              textSecondary,
                              isDark,
                              _sportsScroll),
                          const SizedBox(height: 10),
                          _customChipWithInput(
                              tempSports,
                              (v) => setState(() => tempSports = v),
                              highlightColor,
                              textPrimary,
                              textSecondary,
                              isDark),
                        ],
                      ),
                      isDark),
                ], isDark),

                // HEALTH
                _buildTabWrapper([
                  _innerCard(
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Track Menstrual Cycle',
                              style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                          Switch(
                            value: tempCycle,
                            onChanged: (v) => setState(() => tempCycle = v),
                            activeColor: highlightColor,
                            activeTrackColor: highlightColor.withOpacity(0.3),
                            inactiveThumbColor:
                                isDark ? textSecondary : Colors.white,
                            inactiveTrackColor:
                                (isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.1),
                          ),
                        ],
                      ),
                      isDark),
                  if (tempCycle) ...[
                    const SizedBox(height: 8),
                    _innerCard(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('RECORDED PERIODS',
                                style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2)),
                            const SizedBox(height: 10),
                            if (tempPeriods.isEmpty)
                              Text('No dates recorded yet.',
                                  style: TextStyle(
                                      color: textSecondary.withOpacity(0.5),
                                      fontSize: 11))
                            else
                              SizedBox(
                                height: 35,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: tempPeriods.length,
                                  itemBuilder: (context, index) {
                                    final d = tempPeriods[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ScaleButton(
                                        onTap: () => setState(
                                            () => tempPeriods.removeAt(index)),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color:
                                                highlightColor.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: highlightColor
                                                    .withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                  DateFormat('MMM dd')
                                                      .format(d),
                                                  style: TextStyle(
                                                      color: highlightColor,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              const SizedBox(width: 4),
                                              Icon(Icons.close,
                                                  color: highlightColor,
                                                  size: 10),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      final d = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime.now().subtract(
                                              const Duration(
                                                  days: 365)), // Allow 1 year
                                          lastDate: DateTime.now());
                                      if (d != null && !tempPeriods.contains(d))
                                        setState(() {
                                          tempPeriods.add(d);
                                          tempPeriods.sort();
                                        });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      decoration: BoxDecoration(
                                          color: (isDark
                                                  ? Colors.white
                                                  : Colors.black)
                                              .withOpacity(0.05),
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: Center(
                                          child: Text('Add Past Date',
                                              style: TextStyle(
                                                  color: textPrimary,
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.bold))),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      final today = DateTime(
                                          DateTime.now().year,
                                          DateTime.now().month,
                                          DateTime.now().day);
                                      if (!tempPeriods.contains(today))
                                        setState(() {
                                          tempPeriods.add(today);
                                          tempPeriods.sort();
                                        });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      decoration: BoxDecoration(
                                          color:
                                              highlightColor.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: Center(
                                          child: Text('Got Period Today',
                                              style: TextStyle(
                                                  color: highlightColor,
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.bold))),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        isDark),
                  ],
                  const SizedBox(height: 8),
                  _innerCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CHRONIC CONDITIONS',
                              style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2)),
                          const SizedBox(height: 8),
                          _multiChipSelector([
                            'Diabetes',
                            'Kidney',
                            'Hypertension',
                            'Asthma',
                            ...tempChronic.where((c) => ![
                                  'Diabetes',
                                  'Kidney',
                                  'Hypertension',
                                  'Asthma'
                                ].contains(c))
                          ],
                              tempChronic,
                              (v) => setState(() => tempChronic = v),
                              highlightColor,
                              textSecondary,
                              isDark,
                              _chronicScroll),
                          const SizedBox(height: 10),
                          _customChipWithInput(
                              tempChronic,
                              (v) => setState(() => tempChronic = v),
                              highlightColor,
                              textPrimary,
                              textSecondary,
                              isDark),
                        ],
                      ),
                      isDark),
                  const SizedBox(height: 8),
                  _innerCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TEMPORARY ILLNESS',
                              style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2)),
                          const SizedBox(height: 8),
                          _multiChipSelector([
                            'UTI',
                            'Diarrhea',
                            'Fever',
                            'Vomiting',
                            'Cold',
                            'Constipation',
                            ...tempTemp.where((t) => ![
                                  'UTI',
                                  'Diarrhea',
                                  'Fever',
                                  'Vomiting',
                                  'Cold',
                                  'Constipation'
                                ].contains(t))
                          ],
                              tempTemp,
                              (v) => setState(() => tempTemp = v),
                              highlightColor,
                              textSecondary,
                              isDark,
                              _tempScroll),
                          const SizedBox(height: 10),
                          _customChipWithInput(
                              tempTemp,
                              (v) => setState(() => tempTemp = v),
                              highlightColor,
                              textPrimary,
                              textSecondary,
                              isDark),
                        ],
                      ),
                      isDark),
                  const SizedBox(height: 8),
                  _innerCard(
                      _multilineTextField(
                          'Freeform Notes for AI',
                          tempCustomNotes,
                          (v) => tempCustomNotes = v,
                          textPrimary,
                          textSecondary,
                          isDark),
                      isDark),
                ], isDark),

                // ENVIRONMENT & DIET
                _buildTabWrapper([
                  _innerCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Auto Weather Sync',
                                  style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              Switch(
                                value: tempAutoWeather,
                                onChanged: (v) {
                                  setState(() => tempAutoWeather = v);
                                  if (v) _syncWeather();
                                },
                                activeColor: highlightColor,
                                activeTrackColor:
                                    highlightColor.withOpacity(0.3),
                                inactiveThumbColor:
                                    isDark ? textSecondary : Colors.white,
                                inactiveTrackColor:
                                    (isDark ? Colors.white : Colors.black)
                                        .withOpacity(0.1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Automatically fetch 7-day temperature and humidity trends based on your current location.',
                            style: TextStyle(
                                color: textSecondary,
                                fontSize: 11,
                                height: 1.4),
                          ),
                        ],
                      ),
                      isDark),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: tempAutoWeather ? 0.4 : 1.0,
                    child: IgnorePointer(
                      ignoring: tempAutoWeather,
                      child: _innerCard(
                          Column(
                            children: [
                              _tactileValueButton(
                                  'Temperature',
                                  tempT.toInt(),
                                  0,
                                  50,
                                  '°C',
                                  (v) => setState(() => tempT = v.toDouble()),
                                  highlightColor,
                                  textPrimary,
                                  textSecondary,
                                  isDark,
                                  useInnerCard: false),
                              const SizedBox(height: 8),
                              _tactileValueButton(
                                  'Humidity',
                                  tempH.toInt(),
                                  0,
                                  100,
                                  '%',
                                  (v) => setState(() => tempH = v.toDouble()),
                                  highlightColor,
                                  textPrimary,
                                  textSecondary,
                                  isDark,
                                  useInnerCard: false),
                            ],
                          ),
                          isDark),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _innerCard(
                      _toggleGroup(
                          'CAFFEINE',
                          tempCaf,
                          ['None', 'Low', 'Med', 'High'],
                          (v) => setState(() => tempCaf = v),
                          highlightColor,
                          textSecondary,
                          isDark),
                      isDark),
                  const SizedBox(height: 8),
                  _innerCard(
                      _toggleGroup(
                          'ALCOHOL',
                          tempAlc,
                          ['None', 'Low', 'Med', 'High'],
                          (v) => setState(() => tempAlc = v),
                          highlightColor,
                          textSecondary,
                          isDark),
                      isDark),
                  const SizedBox(height: 8),
                  _innerCard(
                      _toggleGroup(
                          'SALT',
                          tempSalt,
                          ['Low', 'Moderate', 'High'],
                          (v) => setState(() => tempSalt = v),
                          highlightColor,
                          textSecondary,
                          isDark),
                      isDark),
                ], isDark),

                // SCHEDULE & ENGINE
                _buildTabWrapper([
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                            child: _timeSelector(
                                'Wake Up',
                                tempWaking,
                                (v) => setState(() => tempWaking = v),
                                isDark,
                                highlightColor,
                                textPrimary,
                                textSecondary)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _timeSelector(
                                'Sleep',
                                tempSleeping,
                                (v) => setState(() => tempSleeping = v),
                                isDark,
                                highlightColor,
                                textPrimary,
                                textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                            child: _timeSelector(
                                'Work/School Start',
                                tempWorkStart,
                                (v) => setState(() => tempWorkStart = v),
                                isDark,
                                highlightColor,
                                textPrimary,
                                textSecondary)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _timeSelector(
                                'Work/School End',
                                tempWorkEnd,
                                (v) => setState(() => tempWorkEnd = v),
                                isDark,
                                highlightColor,
                                textPrimary,
                                textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _innerCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _toggleGroup(
                              'AI ENGINE',
                              tempEngine,
                              ['NVIDIA', 'Gemini'],
                              (v) => setState(() => tempEngine = v),
                              highlightColor,
                              textSecondary,
                              isDark),
                          const SizedBox(height: 12),
                          Text(
                            tempEngine == 'NVIDIA'
                                ? 'Precision medical-grade plans using Nemotron-3-Super.'
                                : 'High-speed wellness strategy using Gemini 2.5 Flash.',
                            style: TextStyle(
                                color: textSecondary,
                                fontSize: 11,
                                height: 1.4),
                          ),
                        ],
                      ),
                      isDark),
                  const SizedBox(height: 8),
                  _innerCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ALARM BEHAVIOR',
                              style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2)),
                          const SizedBox(height: 12),
                          _settingsToggle('Enable Alarm Sound', tempSound,
                              (v) => setState(() => tempSound = v), isDark, textPrimary, textSecondary, highlightColor),
                          const Divider(height: 20, color: Colors.white10),
                          _settingsToggle('Insistent Alarm (Looping)', tempInsistent,
                              (v) => setState(() => tempInsistent = v), isDark, textPrimary, textSecondary, highlightColor),
                        ],
                      ),
                      isDark),
                ], isDark),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ScaleButton(
              onTap: () {
                final s = waterProvider.settings!;
                s.age = tempAge;
                s.height = tempHeight;
                s.weight = tempWeight;
                s.sex = tempSex;
                s.exerciseFrequency = tempFreq;
                s.exerciseIntensity = tempIntense;
                s.sports = tempSports;
                s.isTrackingCycle = tempCycle;
                s.pastPeriods = tempPeriods;
                s.profession = tempProfession;
                s.activeWeekends = tempActiveWeekends;
                s.customNotes = tempCustomNotes;
                s.chronicConditions = tempChronic;
                s.temporaryIllnesses = tempTemp;
                s.temperature = tempT;
                s.humidity = tempH;
                s.autoWeather = tempAutoWeather;
                s.caffeineLevel = tempCaf;
                s.alcoholLevel = tempAlc;
                s.saltIntake = tempSalt;
                s.isWeightMetric = tempWeightMetric;
                s.isHeightMetric = tempHeightMetric;
                s.aiEngine = tempEngine;
                s.wakingTime = tempWaking;
                s.sleepingTime = tempSleeping;
                s.workStartTime = tempWorkStart;
                s.workEndTime = tempWorkEnd;
                s.enableAlarmSound = tempSound;
                s.insistentAlarm = tempInsistent;
                waterProvider.updateSettings(s);
                Navigator.pop(context);
                HapticFeedback.heavyImpact();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient:
                      LinearGradient(colors: [highlightColor, accentColor]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: highlightColor.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: Center(
                  child: Text('Save Configuration',
                      style: TextStyle(
                          color: isDark ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.5)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabWrapper(List<Widget> children, bool isDark) {
    return ExcludeSemantics(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: children,
      ),
    );
  }

  Widget _uniformCard(
      String title, List<Widget> children, Color cardColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(title.toUpperCase(),
                style: TextStyle(
                    color:
                        (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2)),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _innerCard(Widget child, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.03)),
      ),
      child: child,
    );
  }

  void _showCustomTimePicker(
      String label,
      TimeOfDay initialTime,
      Function(TimeOfDay) onTimeChanged,
      bool isDark,
      Color highlightColor,
      Color textPrimary,
      Color textSecondary) {
    int hour = initialTime.hourOfPeriod == 0 ? 12 : initialTime.hourOfPeriod;
    int minute = initialTime.minute;
    bool isAm = initialTime.period == DayPeriod.am;

    final hourController = FixedExtentScrollController(initialItem: hour - 1);
    final minuteController = FixedExtentScrollController(initialItem: minute);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E242E) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
                left: 30,
                right: 30,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  isDark ? const Color(0xFF252D3D) : Colors.white,
                  isDark ? const Color(0xFF1E242E) : const Color(0xFFF8FBFF),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(35)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: highlightColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(label,
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 30),

                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Unified Glowing Focus Card
                      Container(
                        height: 65,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: highlightColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: highlightColor.withOpacity(0.15),
                              width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: highlightColor.withOpacity(0.05),
                                blurRadius: 20,
                                spreadRadius: 2)
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
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -1,
                                        )),
                                  ),
                                  childCount: 12,
                                ),
                              ),
                            ),

                            Text(':',
                                style: TextStyle(
                                    color: highlightColor.withOpacity(0.5),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold)),

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
                                    child:
                                        Text(index.toString().padLeft(2, '0'),
                                            style: TextStyle(
                                              color: textPrimary,
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
                            _amPmSelector(
                                isAm,
                                (val) => setModalState(() => isAm = val),
                                highlightColor,
                                isDark),
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
                          colors: [
                            highlightColor,
                            highlightColor.withOpacity(0.8)
                          ],
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
                      child: Center(
                        child: Text('Confirm Schedule',
                            style: TextStyle(
                              color: isDark ? Colors.black : Colors.white,
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

  Widget _amPmSelector(
      bool isAm, Function(bool) onChanged, Color highlightColor, bool isDark) {
    return Container(
      width: 100,
      height: 45,
      margin: const EdgeInsets.only(right: 10, left: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.03),
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
                  BoxShadow(
                      color: highlightColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
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
                    child: Text('AM',
                        style: TextStyle(
                          color: isAm
                              ? (isDark ? Colors.black : Colors.white)
                              : (isDark ? Colors.white38 : Colors.black26),
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
                    child: Text('PM',
                        style: TextStyle(
                          color: !isAm
                              ? (isDark ? Colors.black : Colors.white)
                              : (isDark ? Colors.white38 : Colors.black26),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1,
                        )),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeSelector(
      String label,
      TimeOfDay time,
      Function(TimeOfDay) onChanged,
      bool isDark,
      Color highlightColor,
      Color textPrimary,
      Color textSecondary,
      {bool useInnerCard = true}) {
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(time.format(context),
            style: TextStyle(
                color: textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
      ],
    );

    return ScaleButton(
      onTap: () => _showCustomTimePicker(label, time, onChanged, isDark,
          highlightColor, textPrimary, textSecondary),
      child: useInnerCard ? _innerCard(content, isDark) : content,
    );
  }

  Widget _toggleGroup(
      String label,
      String current,
      List<String> options,
      Function(String) onChanged,
      Color highlightColor,
      Color textSecondary,
      bool isDark) {
    int selectedIndex = options.indexOf(current);
    if (selectedIndex == -1) selectedIndex = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, constraints) {
          double width = constraints.maxWidth;
          double itemWidth = width / options.length;

          return Container(
            height: 36,
            decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12)),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  left: selectedIndex * itemWidth,
                  width: itemWidth,
                  top: 0,
                  bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      decoration: BoxDecoration(
                          color: highlightColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                                color: highlightColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2))
                          ]),
                    ),
                  ),
                ),
                Row(
                  children: options.map((o) {
                    bool sel = current == o;
                    return Expanded(
                      child: ScaleButton(
                        onTap: () => onChanged(o),
                        child: Container(
                          color: Colors.transparent,
                          alignment: Alignment.center,
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            style: TextStyle(
                                color: sel
                                    ? (isDark ? Colors.black : Colors.white)
                                    : textSecondary,
                                fontSize: 10,
                                fontWeight:
                                    sel ? FontWeight.w900 : FontWeight.bold),
                            child: Text(o),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _multiChipSelector(
      List<String> options,
      List<String> selected,
      Function(List<String>) onChanged,
      Color highlightColor,
      Color textSecondary,
      bool isDark,
      ScrollController controller) {
    final cardInnerColor =
        (isDark ? Colors.white : Colors.black).withOpacity(0.05);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        bool isAtStart = true;
        bool isAtEnd = false;
        if (controller.hasClients) {
          isAtStart = controller.offset <= 0;
          isAtEnd =
              controller.offset >= (controller.position.maxScrollExtent - 5);
        }

        return Container(
          constraints: const BoxConstraints(maxHeight: 50),
          child: Row(
            children: [
              ScaleButton(
                onTap: isAtStart
                    ? null
                    : () {
                        controller.animateTo(
                          (controller.offset - 150)
                              .clamp(0, controller.position.maxScrollExtent),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                        HapticFeedback.mediumImpact();
                      },
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isAtStart
                        ? textSecondary.withOpacity(0.1)
                        : highlightColor.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.chevron_left,
                      color: isAtStart
                          ? textSecondary.withOpacity(0.3)
                          : Colors.white,
                      size: 12),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black)
                        .withOpacity(0.03),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: SingleChildScrollView(
                      controller: controller,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: options.map((o) {
                          bool sel = selected.contains(o);
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ScaleButton(
                              onTap: () {
                                final newList = List<String>.from(selected);
                                if (!sel)
                                  newList.add(o);
                                else
                                  newList.remove(o);
                                onChanged(newList);
                                HapticFeedback.lightImpact();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? highlightColor.withOpacity(0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: sel
                                        ? highlightColor
                                        : textSecondary.withOpacity(0.2),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (sel) ...[
                                      Icon(Icons.check_circle,
                                          color: highlightColor, size: 12),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      o,
                                      style: TextStyle(
                                        color: sel
                                            ? highlightColor
                                            : textSecondary,
                                        fontSize: 11,
                                        fontWeight: sel
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ScaleButton(
                onTap: isAtEnd
                    ? null
                    : () {
                        controller.animateTo(
                          (controller.offset + 150)
                              .clamp(0, controller.position.maxScrollExtent),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                        HapticFeedback.mediumImpact();
                      },
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isAtEnd
                        ? textSecondary.withOpacity(0.1)
                        : highlightColor.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.chevron_right,
                      color: isAtEnd
                          ? textSecondary.withOpacity(0.3)
                          : Colors.white,
                      size: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tactileValueButton(
      String label,
      int val,
      int min,
      int max,
      String unit,
      Function(int) onChanged,
      Color highlightColor,
      Color textPrimary,
      Color textSecondary,
      bool isDark,
      {bool useInnerCard = true,
      bool showUnitToggle = false,
      VoidCallback? onUnitToggle}) {
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: TextStyle(
                color: textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
                child: Text(_formatValue(val, unit, label),
                    style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900),
                    overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                  color: highlightColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(unit,
                  style: TextStyle(
                      color: highlightColor,
                      fontSize: 8,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );

    return ScaleButton(
      onTap: () => _showSliderPopup(label, val, min, max, unit, onChanged,
          highlightColor, textPrimary, textSecondary, isDark,
          showUnitToggle: showUnitToggle, onUnitToggle: onUnitToggle),
      child: useInnerCard ? _innerCard(content, isDark) : content,
    );
  }

  String _formatValue(int val, String unit, String label) {
    if (unit == 'ft' && label.contains('Height')) {
      int feet = val ~/ 12;
      int inches = val % 12;
      return "$feet' $inches\"";
    }
    return '$val';
  }

  Widget _tactileSexButton(
      String current,
      Function(String) onChanged,
      Color highlightColor,
      Color textPrimary,
      Color textSecondary,
      bool isDark) {
    return ScaleButton(
      onTap: () => onChanged(current == 'Male' ? 'Female' : 'Male'),
      child: _innerCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SEX',
                  style: TextStyle(
                      color: textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                      child: Text(current,
                          style: TextStyle(
                              color: textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900),
                          overflow: TextOverflow.ellipsis)),
                  Icon(current == 'Male' ? Icons.male : Icons.female,
                      color: highlightColor, size: 18),
                ],
              ),
            ],
          ),
          isDark),
    );
  }

  void _showSliderPopup(
      String label,
      int initialVal,
      int min,
      int max,
      String unit,
      Function(int) onChanged,
      Color highlightColor,
      Color textPrimary,
      Color textSecondary,
      bool isDark,
      {bool showUnitToggle = false,
      VoidCallback? onUnitToggle}) {
    int currentLocalVal = initialVal;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E242E) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(builder: (context, setModalState) {
        // Re-calculate unit if toggled
        String currentUnit = unit;
        int currentMin = min;
        int currentMax = max;

        if (showUnitToggle) {
          if (label.contains('Weight')) {
            currentUnit = tempWeightMetric ? 'kg' : 'lb';
            currentMin = tempWeightMetric ? 30 : 66;
            currentMax = tempWeightMetric ? 200 : 440;
          }
          if (label.contains('Height')) {
            currentUnit = tempHeightMetric ? 'cm' : 'ft';
            currentMin = tempHeightMetric ? 100 : 36;
            currentMax = tempHeightMetric ? 250 : 96;
          }
        }

        return Container(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: textSecondary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  if (showUnitToggle)
                    ScaleButton(
                      onTap: () {
                        onUnitToggle?.call();
                        // Adjust currentLocalVal when switching
                        if (label.contains('Weight')) {
                          currentLocalVal = tempWeightMetric
                              ? (currentLocalVal / 2.20462).round()
                              : (currentLocalVal * 2.20462).round();
                        } else if (label.contains('Height')) {
                          currentLocalVal = tempHeightMetric
                              ? (currentLocalVal * 2.54).round()
                              : (currentLocalVal / 2.54).round();
                        }
                        setModalState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            border: Border.all(
                                color: highlightColor.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text('Switch Unit',
                            style: TextStyle(
                                color: highlightColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                  _formatValue(currentLocalVal, currentUnit, label) +
                      (currentUnit == 'ft' ? '' : ' $currentUnit'),
                  style: TextStyle(
                      color: highlightColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 30),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: highlightColor,
                  inactiveTrackColor: highlightColor.withOpacity(0.1),
                  thumbColor: highlightColor,
                  overlayColor: highlightColor.withOpacity(0.1),
                  trackHeight: 8,
                ),
                child: Slider(
                  value: currentLocalVal
                      .toDouble()
                      .clamp(currentMin.toDouble(), currentMax.toDouble()),
                  min: currentMin.toDouble(),
                  max: currentMax.toDouble(),
                  onChanged: (v) {
                    setModalState(() => currentLocalVal = v.toInt());
                    onChanged(v.toInt());
                  },
                ),
              ),
              const SizedBox(height: 30),
              ScaleButton(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                      color: highlightColor,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Center(
                      child: Text('Confirm',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold))),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _customChipWithInput(
      List<String> selected,
      Function(List<String>) onChanged,
      Color highlightColor,
      Color textPrimary,
      Color textSecondary,
      bool isDark) {
    final controller = TextEditingController();

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 36, // Compact height
            child: TextField(
              controller: controller,
              onSubmitted: (val) {
                if (val.isNotEmpty && !selected.contains(val)) {
                  final newList = List<String>.from(selected)..add(val);
                  onChanged(newList);
                  controller.clear();
                }
              },
              style: TextStyle(color: textPrimary, fontSize: 11),
              decoration: InputDecoration(
                hintText: '+ Add Custom',
                hintStyle: TextStyle(color: textSecondary.withOpacity(0.4)),
                filled: true,
                fillColor:
                    (isDark ? Colors.white : Colors.black).withOpacity(0.04),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 15),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        ScaleButton(
          onTap: () {
            final val = controller.text.trim();
            if (val.isNotEmpty && !selected.contains(val)) {
              final newList = List<String>.from(selected)..add(val);
              onChanged(newList);
              controller.clear();
            }
          },
          child: Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
                color: highlightColor, borderRadius: BorderRadius.circular(25)),
            child: const Icon(Icons.add, color: Colors.white, size: 14),
          ),
        ),
      ],
    );
  }

  Widget _multilineTextField(
      String label,
      String currentVal,
      Function(String) onChanged,
      Color textPrimary,
      Color textSecondary,
      bool isDark,
      {int lines = 4}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: TextStyle(
                color: textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        TextField(
          onChanged: onChanged,
          controller: TextEditingController(text: currentVal)
            ..selection = TextSelection.collapsed(offset: currentVal.length),
          maxLines: lines,
          style: TextStyle(color: textPrimary, fontSize: 12),
          decoration: InputDecoration(
            hintText: lines == 1
                ? 'Enter your profession...'
                : 'e.g., Training for a marathon this week, feeling sick, etc.',
            hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
            filled: true,
            fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          ),
        ),
      ],
    );
  }

  Widget _navIcon(int index, IconData icon, bool isDark, Color accentColor,
      Color highlightColor, Color textSecondary) {
    bool isSelected = _tabController.index == index;
    return Expanded(
      child: ScaleButton(
        onTap: () {
          _tabController.animateTo(index);
          setState(() {});
          HapticFeedback.selectionClick();
        },
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: isSelected ? highlightColor : Colors.transparent,
                borderRadius: BorderRadius.circular(100)),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Icon(icon,
                  key: ValueKey('${index}_${isSelected}'),
                  color: isSelected
                      ? (isDark ? const Color(0xFF141921) : Colors.white)
                      : textSecondary,
                  size: 18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsToggle(
      String label,
      bool value,
      Function(bool) onChanged,
      bool isDark,
      Color textPrimary,
      Color textSecondary,
      Color highlightColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: highlightColor,
          activeTrackColor: highlightColor.withOpacity(0.3),
          inactiveThumbColor: isDark ? textSecondary : Colors.white,
          inactiveTrackColor:
              (isDark ? Colors.white : Colors.black).withOpacity(0.1),
        ),
      ],
    );
  }
}
