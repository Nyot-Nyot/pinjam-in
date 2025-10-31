import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// Small reusable header used across auth screens (logo + title + subtitle)
class AuthHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const AuthHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 112.0,
            height: 112.0,
            decoration: BoxDecoration(
              color: const Color(0x1A8530E4),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Center(
              child: SizedBox(
                width: 64.0,
                height: 64.0,
                child: SvgPicture.asset(
                  'assets/images/logo-purple.svg',
                  fit: BoxFit.contain,
                  placeholderBuilder: (c) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24.0),

          Text(
            title,
            style: GoogleFonts.arimo(
              fontSize: 16.0,
              color: const Color(0xFF8530E4),
            ),
          ),

          if (subtitle != null) ...[
            const SizedBox(height: 8.0),
            SizedBox(
              width: 250.317,
              child: Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: GoogleFonts.arimo(
                  fontSize: 16.0,
                  color: const Color(0xFF4A3D5C),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
