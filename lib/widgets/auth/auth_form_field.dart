import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthFormField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;

  const AuthFormField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.arimo(
            fontSize: 14.0,
            color: const Color(0xFF0C0315),
          ),
        ),
        const SizedBox(height: 8.0),
        Container(
          height: 48.0,
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: const Color(0xFFEBE1F7),
            borderRadius: BorderRadius.circular(20.0),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.08),
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            decoration: InputDecoration.collapsed(
              hintText: hintText,
              hintStyle: GoogleFonts.arimo(
                fontSize: 16.0,
                color: const Color(0xFF4A3D5C),
              ),
            ),
            style: GoogleFonts.arimo(
              fontSize: 16.0,
              color: const Color(0xFF4A3D5C),
            ),
          ),
        ),
      ],
    );
  }
}
