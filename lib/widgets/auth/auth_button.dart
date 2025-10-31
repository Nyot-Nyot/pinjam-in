import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthButton extends StatelessWidget {
  final String text;
  final String iconAsset;
  final VoidCallback? onPressed;
  final bool isLoading;

  const AuthButton({
    super.key,
    required this.text,
    required this.iconAsset,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48.0,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8530E4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          elevation: 12,
          shadowColor: const Color.fromRGBO(0, 0, 0, 0.12),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox.shrink()
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16.0,
                    height: 16.0,
                    child: SvgPicture.asset(
                      iconAsset,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    text,
                    style: GoogleFonts.arimo(
                      fontSize: 14.0,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
