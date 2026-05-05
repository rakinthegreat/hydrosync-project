import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/water_provider.dart';
import '../models/user_settings.dart';
import '../services/sync_service.dart';
import '../widgets/scale_button.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final SyncService _sync = SyncService();

  // Local state for setup
  late int tempAge;
  late double tempWeight;
  late double tempHeight;
  late String tempSex;
  late String tempProfession;
  late List<String> tempChronic;
  late List<String> tempTemp;
  late bool tempCycle;
  late List<DateTime> tempPeriods;
  late bool tempWeightMetric;
  late bool tempHeightMetric;
  bool _isSigningIn = false;
  bool _isFinishing = false;

  @override
  void initState() {
    super.initState();
    final s = Provider.of<WaterProvider>(context, listen: false).settings!;
    tempAge = s.age;
    tempWeight = s.weight;
    tempHeight = s.height;
    tempSex = '';
    tempProfession = '';
    tempChronic = [];
    tempTemp = [];
    tempCycle = s.isTrackingCycle;
    tempPeriods = List.from(s.pastPeriods);
    tempWeightMetric = s.isWeightMetric;
    tempHeightMetric = s.isHeightMetric;
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutQuart);
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() async {
    setState(() => _isFinishing = true);
    final provider = Provider.of<WaterProvider>(context, listen: false);
    final s = provider.settings!;

    s.age = tempAge;
    s.weight = tempWeight;
    s.height = tempHeight;
    s.sex = tempSex;
    s.profession = tempProfession;
    s.chronicConditions = tempChronic;
    s.temporaryIllnesses = tempTemp;
    s.isTrackingCycle = tempCycle;
    s.pastPeriods = tempPeriods;
    s.isWeightMetric = tempWeightMetric;
    s.isHeightMetric = tempHeightMetric;
    s.isOnboarded = true;

    final originalEngine = s.aiEngine;
    s.aiEngine = 'Gemini';

    await provider.updateSettings(s);
    await provider.applyAiStrategy();

    if (originalEngine != 'Gemini') {
      s.aiEngine = 'NVIDIA';
      await provider.updateSettings(s);
    }

    setState(() => _isFinishing = false);

    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isSigningIn = true);
    final user = await _sync.signInWithGoogle();
    setState(() => _isSigningIn = false);

    if (user != null) {
      // Cloud recovery logic is handled in WaterProvider.init or we can trigger it here
      final provider = Provider.of<WaterProvider>(context, listen: false);
      final cloud = await _sync.restoreAll();
      if (cloud != null && cloud.settings != null) {
        cloud.settings!.isOnboarded = true;
        await provider.updateSettings(cloud.settings!);
        if (mounted) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      } else {
        // No cloud data, continue with onboarding but user is signed in
        _nextPage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Provider.of<WaterProvider>(context).settings?.isDarkMode ?? true;

    final bgColor = isDark ? const Color(0xFF1B232A) : const Color(0xFFDCE4E8);
    final cardColor =
        isDark ? const Color(0xFF242E38) : const Color(0xFFE5ECF0);
    final highlightColor =
        isDark ? const Color(0xFF78909C) : const Color(0xFF608DA1);
    final textSecondary =
        isDark ? const Color(0xFF607D8B) : const Color(0xFF546E7A);
    final textPrimary =
        isDark ? const Color(0xFFCFD8DC) : const Color(0xFF455A64);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (v) => setState(() => _currentPage = v),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWelcomePage(
                      isDark, highlightColor, textPrimary, textSecondary),
                  _buildIdentityPage(isDark, cardColor, highlightColor,
                      textPrimary, textSecondary),
                  _buildLifestylePage(isDark, cardColor, highlightColor,
                      textPrimary, textSecondary),
                  _buildBiologicalPage(isDark, cardColor, highlightColor,
                      textPrimary, textSecondary),
                  _buildFinalPage(
                      isDark, highlightColor, textPrimary, textSecondary),
                ],
              ),
            ),
            _buildBottomControls(highlightColor, textPrimary, textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage(
      bool isDark, Color highlight, Color primary, Color secondary) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            textAlign: TextAlign.left,
            text: TextSpan(
              style: TextStyle(
                  color: primary, fontSize: 18, fontWeight: FontWeight.w300),
              children: [
                const TextSpan(text: 'Welcome to\n'),
                TextSpan(
                  text: 'hydrosync',
                  style: TextStyle(
                      color: highlight,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Your intelligent hydration strategist.',
            textAlign: TextAlign.left,
            style: TextStyle(color: secondary, fontSize: 16),
          ),
          const SizedBox(height: 80),
          Text('Choose your theme'.toUpperCase(),
              style: TextStyle(
                  color: secondary,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          const SizedBox(height: 12),
          _buildThemeChooser(isDark, primary, secondary),
          const SizedBox(height: 40),
          RichText(
            textAlign: TextAlign.left,
            text: TextSpan(
              style: TextStyle(
                color: secondary,
                fontSize: 12,
                height: 1.5,
              ),
              children: [
                const TextSpan(
                    text: 'By proceeding, you agree to our terms and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: TextStyle(
                    color: highlight,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _showPrivacyPolicy(
                        isDark, highlight, primary, secondary),
                ),
                const TextSpan(
                    text: '. We value your biological data security.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(
      bool isDark, Color highlight, Color primary, Color secondary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B232A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('PRIVACY POLICY',
                      style: TextStyle(
                          color: highlight,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          fontSize: 12)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: secondary),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOUR DATA, YOUR HEALTH',
                          style: TextStyle(
                              color: primary,
                              fontSize: 14,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Divider(color: secondary.withOpacity(0.1)),
                      const SizedBox(height: 12),
                      Text(
                        'HydroSync collects minimal biometric data (weight, height, age) and environmental data to calculate your personalized hydration strategy via integrated AI models.\n\n'
                        '1. AI STRATEGY: Your metrics are used as inputs for the AI Strategist (powered by NVIDIA/Gemini) to generate your 7-day hydration plan. This data is processed anonymously.\n'
                        '2. DATA OWNERSHIP: We NEVER read or sell your biological or behavioral data to third parties.\n'
                        '3. LOCAL PRIVACY: Most calculations happen on-device. When AI inference is required, only necessary, non-identifiable metrics are transmitted.\n'
                        '4. LOCATION: Used only for local weather adjustments to the AI model and is never stored permanently on our servers.\n\n'
                        'By using HydroSync, you consent to the use of AI to enhance your health monitoring experience.',
                        style: TextStyle(
                            color: primary.withOpacity(0.5),
                            height: 1.4,
                            fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeChooser(bool isDark, Color primary, Color secondary) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _themeButton(false, Icons.light_mode_outlined, !isDark),
          _themeButton(true, Icons.dark_mode_outlined, isDark),
        ],
      ),
    );
  }

  Widget _themeButton(bool dark, IconData icon, bool active) {
    return ScaleButton(
      onTap: () =>
          Provider.of<WaterProvider>(context, listen: false).toggleTheme(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? (dark ? const Color(0xFF242E38) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Icon(icon,
            color: active ? (dark ? Colors.white : Colors.black) : Colors.grey,
            size: 20),
      ),
    );
  }

  Widget _buildIdentityPage(bool isDark, Color cardColor, Color highlight,
      Color primary, Color secondary) {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('IDENTITY',
              style: TextStyle(
                  color: highlight,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontSize: 12)),
          const SizedBox(height: 10),
          Text('Who are we hydrating?',
              style: TextStyle(
                  color: primary, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 30),
          _googleSignInButton(primary, isDark),
          const SizedBox(height: 30),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('OR FILL MANUALLY',
                    style: TextStyle(
                        color: secondary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 30),
          _buildInputRow(
              'Age',
              tempAge,
              (v) => setState(() => tempAge = v.toInt()),
              1,
              100,
              primary,
              secondary,
              isDark),
          const SizedBox(height: 15),
          _buildInputRow(
              'Weight',
              tempWeight.toInt(),
              (v) => setState(() => tempWeight = v.toDouble()),
              tempWeightMetric ? 30 : 60,
              tempWeightMetric ? 200 : 450,
              primary,
              secondary,
              isDark,
              unit: tempWeightMetric ? 'kg' : 'lb',
              onUnitToggle: () => setState(() {
                    if (tempWeightMetric) {
                      tempWeight = tempWeight * 2.20462;
                    } else {
                      tempWeight = tempWeight / 2.20462;
                    }
                    tempWeightMetric = !tempWeightMetric;
                  })),
          const SizedBox(height: 15),
          _buildInputRow(
              'Height',
              tempHeight.toInt(),
              (v) => setState(() => tempHeight = v.toDouble()),
              tempHeightMetric ? 100 : 36,
              tempHeightMetric ? 250 : 100,
              primary,
              secondary,
              isDark,
              unit: tempHeightMetric ? 'cm' : 'in',
              onUnitToggle: () => setState(() {
                    if (tempHeightMetric) {
                      tempHeight = tempHeight * 0.393701;
                    } else {
                      tempHeight = tempHeight / 0.393701;
                    }
                    tempHeightMetric = !tempHeightMetric;
                  })),
          const SizedBox(height: 15),
          _buildSelectableList(
              'Sex',
              tempSex,
              (v) => setState(() => tempSex = v),
              ['Male', 'Female'],
              primary,
              secondary,
              isDark),
        ],
      ),
    );
  }

  Widget _googleSignInButton(Color primary, bool isDark) {
    return ScaleButton(
      onTap: _handleGoogleSignIn,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: primary.withOpacity(0.1)),
        ),
        child: _isSigningIn
            ? const Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.login, size: 18),
                  const SizedBox(width: 10),
                  Text('Sign in with Google',
                      style: TextStyle(
                          color: primary, fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }

  Widget _buildLifestylePage(bool isDark, Color cardColor, Color highlight,
      Color primary, Color secondary) {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LIFESTYLE',
              style: TextStyle(
                  color: highlight,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontSize: 12)),
          const SizedBox(height: 10),
          Text('Tell us about your life.',
              style: TextStyle(
                  color: primary, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 30),
          _buildSelectableList(
              'Profession',
              tempProfession,
              (v) => setState(() => tempProfession = v),
              [
                'Student',
                'Office Worker',
                'Active',
                'Field Work',
                'Athlete',
                'Custom'
              ],
              primary,
              secondary,
              isDark),
          if (tempProfession == 'Custom') ...[
            const SizedBox(height: 15),
            _buildCustomTextField('Describe your profession...',
                (v) => tempProfession = v, primary, secondary, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildBiologicalPage(bool isDark, Color cardColor, Color highlight,
      Color primary, Color secondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 50),
            Text('BIOLOGICAL',
                style: TextStyle(
                    color: highlight,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontSize: 12)),
            const SizedBox(height: 10),
            Text('Health & Conditions.',
                style: TextStyle(
                    color: primary, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 30),
            _buildMultiSelect(
                'Chronic Conditions',
                tempChronic,
                (v) => setState(() => tempChronic = v),
                ['Kidney', 'Heart', 'Diabetes', 'Hypertension', 'Asthma'],
                primary,
                secondary,
                isDark),
            const SizedBox(height: 10),
            _buildCustomAddRow(
                'Add other condition...',
                (v) => setState(() => tempChronic.add(v)),
                primary,
                secondary,
                isDark),
            const SizedBox(height: 20),
            _buildMultiSelect(
                'Temporary Illnesses',
                tempTemp,
                (v) => setState(() => tempTemp = v),
                ['Fever', 'Cold/Flu', 'Diarrhea', 'Fatigue'],
                primary,
                secondary,
                isDark),
            const SizedBox(height: 10),
            _buildCustomAddRow(
                'Add other illness...',
                (v) => setState(() => tempTemp.add(v)),
                primary,
                secondary,
                isDark),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TRACK MENSTRUAL CYCLE',
                        style: TextStyle(
                            color: secondary,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                    Text('For hormonal hydration tracking',
                        style: TextStyle(
                            color: secondary.withOpacity(0.5), fontSize: 10)),
                  ],
                ),
                Switch(
                  value: tempCycle,
                  onChanged: (v) => setState(() => tempCycle = v),
                  activeColor: highlight,
                  activeTrackColor: highlight.withOpacity(0.3),
                  inactiveThumbColor: isDark ? secondary : Colors.white,
                  inactiveTrackColor:
                      (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                ),
              ],
            ),
            if (tempCycle) ...[
              const SizedBox(height: 15),
              _buildPeriodDatePicker(primary, highlight, secondary, isDark),
            ],
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodDatePicker(
      Color primary, Color highlight, Color secondary, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RECORDED PERIODS',
            style: TextStyle(
                color: secondary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        const SizedBox(height: 10),
        if (tempPeriods.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tempPeriods.length,
              itemBuilder: (context, index) {
                final d = tempPeriods[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ScaleButton(
                    onTap: () => setState(() => tempPeriods.removeAt(index)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: highlight.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: highlight.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Text(DateFormat('MMM dd').format(d),
                              style: TextStyle(
                                  color: highlight,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 5),
                          Icon(Icons.close, color: highlight, size: 12),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 10),
        ScaleButton(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 90)),
              lastDate: DateTime.now(),
            );
            if (d != null) setState(() => tempPeriods.add(d));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 14, color: highlight),
                const SizedBox(width: 8),
                Text('Add Period Start Date',
                    style: TextStyle(
                        color: primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiSelect(
      String label,
      List<String> selected,
      Function(List<String>) onSelected,
      List<String> options,
      Color primary,
      Color secondary,
      bool isDark) {
    // Combine hardcoded options and custom selected items
    final allChips = {...options, ...selected}.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: TextStyle(
                color: secondary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allChips.map((o) {
            bool active = selected.contains(o);
            return ScaleButton(
              onTap: () {
                final newList = List<String>.from(selected);
                if (active)
                  newList.remove(o);
                else
                  newList.add(o);
                onSelected(newList);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: active
                      ? primary.withOpacity(0.1)
                      : (isDark ? Colors.white : Colors.black)
                          .withOpacity(0.04),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: active
                          ? primary.withOpacity(0.3)
                          : Colors.transparent),
                ),
                child: Text(o,
                    style: TextStyle(
                        color: active ? primary : secondary,
                        fontSize: 11,
                        fontWeight:
                            active ? FontWeight.bold : FontWeight.normal)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCustomTextField(String hint, Function(String) onChanged,
      Color primary, Color secondary, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        onChanged: onChanged,
        style: TextStyle(color: primary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: secondary.withOpacity(0.5)),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildCustomAddRow(String hint, Function(String) onAdd, Color primary,
      Color secondary, bool isDark) {
    final controller = TextEditingController();
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(color: primary, fontSize: 13),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: secondary.withOpacity(0.4)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 15),
              ),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  onAdd(v.trim());
                  controller.clear();
                }
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline,
                color: primary.withOpacity(0.5), size: 20),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onAdd(controller.text.trim());
                controller.clear();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFinalPage(
      bool isDark, Color highlight, Color primary, Color secondary) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome, size: 80, color: Color(0xFF78909C)),
          const SizedBox(height: 40),
          Text('All set.',
              style: TextStyle(
                  color: primary, fontSize: 32, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          Text(
            'We\'re ready to generate your first hydration strategy.',
            textAlign: TextAlign.center,
            style: TextStyle(color: secondary, fontSize: 16),
          ),
          const SizedBox(height: 60),
          ScaleButton(
            onTap: _finishOnboarding,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              decoration: BoxDecoration(
                color: highlight,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                      color: highlight.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10))
                ],
              ),
              child: _isFinishing
                  ? const Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)))
                  : const Text('Start Hydrosyncing',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(Color highlight, Color primary, Color secondary) {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            ScaleButton(
              onTap: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut),
              child: Text('Back',
                  style:
                      TextStyle(color: secondary, fontWeight: FontWeight.bold)),
            )
          else
            const SizedBox.shrink(),
          Row(
            children: List.generate(
                5,
                (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? highlight
                            : secondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    )),
          ),
          if (_currentPage < 4)
            ScaleButton(
              onTap: _nextPage,
              child: Text('Next',
                  style:
                      TextStyle(color: highlight, fontWeight: FontWeight.bold)),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildInputRow(String label, int value, Function(int) onChanged,
      int min, int max, Color primary, Color secondary, bool isDark,
      {String? unit, VoidCallback? onUnitToggle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label.toUpperCase(),
                style: TextStyle(
                    color: secondary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            if (onUnitToggle != null)
              ScaleButton(
                onTap: onUnitToggle,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(unit?.toUpperCase() ?? "",
                      style: TextStyle(
                          color: primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: primary.withOpacity(0.3),
                    inactiveTrackColor: primary.withOpacity(0.1),
                    thumbColor: primary,
                    trackHeight: 2,
                  ),
                  child: Slider(
                    value:
                        value.toDouble().clamp(min.toDouble(), max.toDouble()),
                    min: min.toDouble(),
                    max: max.toDouble(),
                    onChanged: (v) => onChanged(v.toInt()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('$value${unit ?? ""}',
                  style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectableList(
      String label,
      String current,
      Function(String) onSelected,
      List<String> options,
      Color primary,
      Color secondary,
      bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: TextStyle(
                color: secondary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            bool active = current == o;
            return ScaleButton(
              onTap: () => onSelected(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: active
                      ? primary.withOpacity(0.1)
                      : (isDark ? Colors.white : Colors.black)
                          .withOpacity(0.04),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: active
                          ? primary.withOpacity(0.3)
                          : Colors.transparent),
                ),
                child: Text(o,
                    style: TextStyle(
                        color: active ? primary : secondary,
                        fontSize: 12,
                        fontWeight:
                            active ? FontWeight.bold : FontWeight.normal)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
