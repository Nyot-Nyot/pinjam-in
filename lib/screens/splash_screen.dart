import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinjam_in/screens/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnim = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8530E4),
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // White rounded container (176x176)
                  Container(
                    width: 176.0,
                    height: 176.0,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(40.0, 40.0, 40.0, 0.0),
                      child: SizedBox(
                        height: 96.0,
                        width: double.infinity,
                        child: Center(
                          // The Figma frame centers the composed logo inside the 96px area.
                          child: SizedBox(
                            width: 96.0,
                            height: 96.0,
                            child: _LogoSvg(),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: 152.0,
                    child: Column(
                      children: [
                        Text(
                          'Pinjam.in!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.arimo(
                            fontSize: 32.0,
                            height: 1.3,
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          'The Lending Library',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.arimo(
                            fontSize: 16.0,
                            height: 1.5,
                            color: const Color(0xFFABABAB),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Home placeholder removed; splash now navigates to the real LoginScreen.

class _LogoSvg extends StatelessWidget {
  const _LogoSvg({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const String assetPath = 'assets/images/logo.svg';
    try {
      // Apply a color filter so a white-only SVG becomes visible on the
      // white container by recoloring it to the brand purple used elsewhere.
      return SvgPicture.asset(
        assetPath,
        fit: BoxFit.contain,
        semanticsLabel: 'App logo',
        // Recolor the SVG to the splash purple so white-on-white SVGs are visible.
        colorFilter: const ColorFilter.mode(Color(0xFF8530E4), BlendMode.srcIn),
        placeholderBuilder: (context) => const SizedBox.shrink(),
      );
    } catch (e) {
      // If loading fails, show a simple purple circular placeholder the same
      // size as the intended logo so layout doesn't shift.
      return Container(
        width: 96.0,
        height: 96.0,
        decoration: const BoxDecoration(
          color: Color(0xFF8530E4),
          shape: BoxShape.circle,
        ),
      );
    }
  }
}
