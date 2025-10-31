import 'package:flutter/material.dart';

class LargeIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;

  const LargeIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    // Use withAlpha to avoid precision issues from withOpacity
    final bg = backgroundColor ?? Theme.of(context).primaryColor.withAlpha(20);
    final ic = iconColor ?? Theme.of(context).primaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: size * 0.55, color: ic),
        ),
      ),
    );
  }
}
