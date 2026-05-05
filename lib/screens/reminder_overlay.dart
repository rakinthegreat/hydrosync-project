import 'package:flutter/material.dart';

class ReminderOverlay extends StatelessWidget {
  const ReminderOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Hydration Time!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00D2FF),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Did you drink enough water this hour?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 50),
              // Placeholder for Lottie animation
              const Icon(Icons.water_drop, size: 150, color: Color(0xFF00D2FF)),
              const SizedBox(height: 100),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionButton(context, 'Yes!', Colors.greenAccent, () => Navigator.pop(context)),
                  _actionButton(context, 'Not yet', Colors.redAccent, () => Navigator.pop(context)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(BuildContext context, String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }
}
