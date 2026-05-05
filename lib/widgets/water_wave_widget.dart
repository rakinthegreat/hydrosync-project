import 'package:flutter/material.dart';
import 'package:wave/config.dart';
import 'package:wave/wave.dart';

class WaterWaveWidget extends StatelessWidget {
  final double progress; // 0.0 to 1.0

  const WaterWaveWidget({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(seconds: 1),
      height: MediaQuery.of(context).size.height * progress,
      width: double.infinity,
      child: WaveWidget(
        config: CustomConfig(
          gradients: [
            [const Color(0xFF00D2FF), const Color(0xFF3A7BD5)],
            [const Color(0xFF3A7BD5), const Color(0xFF00D2FF)],
            [const Color(0xFF00D2FF).withOpacity(0.5), const Color(0xFF3A7BD5).withOpacity(0.5)],
          ],
          durations: [10000, 15000, 20000],
          heightPercentages: [0.01, 0.02, 0.03],
          blur: const MaskFilter.blur(BlurStyle.solid, 10),
          gradientBegin: Alignment.bottomLeft,
          gradientEnd: Alignment.topRight,
        ),
        waveAmplitude: 10,
        size: const Size(double.infinity, double.infinity),
      ),
    );
  }
}
