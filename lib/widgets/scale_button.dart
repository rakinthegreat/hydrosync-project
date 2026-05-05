import 'package:flutter/material.dart';

class ScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const ScaleButton({super.key, required this.child, this.onTap});

  @override
  State<ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<ScaleButton> with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _scale = 0.96),
      onTapUp: widget.onTap == null ? null : (_) {
        setState(() => _scale = 1.0);
        widget.onTap?.call();
      },
      onTapCancel: widget.onTap == null ? null : () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale, 
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}
