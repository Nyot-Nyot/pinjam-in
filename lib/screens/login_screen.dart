import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinjam_in/screens/home_screen.dart';
import 'package:pinjam_in/screens/register_screen.dart';

// Use local SVG assets placed under assets/images/
const String _logoAsset = 'assets/images/logo-purple.svg';
const String _enterIconAsset = 'assets/images/enter.svg';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  static const double _cardWidth = 329.6;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6EFFD), // frame background
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.only(left: 32.0, right: 32.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _cardWidth),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Top container with icon and headings
                          SizedBox(
                            width: _cardWidth,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Rounded icon container (112)
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
                                        _logoAsset,
                                        fit: BoxFit.contain,
                                        placeholderBuilder: (c) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 24.0),

                                // Heading
                                SizedBox(
                                  width: 119.8,
                                  child: Text(
                                    'Selamat Datang',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.arimo(
                                      fontSize: 16.0,
                                      height: 24.0 / 16.0,
                                      color: const Color(0xFF8530E4),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8.0),

                                SizedBox(
                                  width: 157.283,
                                  child: Text(
                                    'Masuk ke akun Anda',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.arimo(
                                      fontSize: 16.0,
                                      height: 24.0 / 16.0,
                                      color: const Color(0xFF4A3D5C),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40.0),

                          // Form
                          SizedBox(
                            width: _cardWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Email field
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Email',
                                      style: GoogleFonts.arimo(
                                        fontSize: 14.0,
                                        color: const Color(0xFF0C0315),
                                      ),
                                    ),
                                    const SizedBox(height: 8.0),
                                    Container(
                                      height: 48.0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12.0,
                                        vertical: 4.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEBE1F7),
                                        borderRadius: BorderRadius.circular(
                                          20.0,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color.fromRGBO(
                                              0,
                                              0,
                                              0,
                                              0.08,
                                            ),
                                            offset: Offset(0, 2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'nama@email.com',
                                          style: GoogleFonts.arimo(
                                            fontSize: 16.0,
                                            color: const Color(0xFF4A3D5C),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12.0),

                                // Password field
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Kata Sandi',
                                      style: GoogleFonts.arimo(
                                        fontSize: 14.0,
                                        color: const Color(0xFF0C0315),
                                      ),
                                    ),
                                    const SizedBox(height: 8.0),
                                    Container(
                                      height: 48.0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12.0,
                                        vertical: 4.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEBE1F7),
                                        borderRadius: BorderRadius.circular(
                                          20.0,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color.fromRGBO(
                                              0,
                                              0,
                                              0,
                                              0.08,
                                            ),
                                            offset: Offset(0, 2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Masukkan kata sandi',
                                          style: GoogleFonts.arimo(
                                            fontSize: 16.0,
                                            color: const Color(0xFF4A3D5C),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24.0),

                                // Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 48.0,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF8530E4),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          20.0,
                                        ),
                                      ),
                                      elevation: 12,
                                      shadowColor: const Color.fromRGBO(
                                        0,
                                        0,
                                        0,
                                        0.12,
                                      ),
                                    ),
                                    onPressed: () {
                                      // Skip authentication for now — navigate directly to Home
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                          builder: (_) => const HomeScreen(),
                                        ),
                                      );
                                    },
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 16.0,
                                          height: 16.0,
                                          child: SvgPicture.asset(
                                            _enterIconAsset,
                                            color: Colors.white,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                        const SizedBox(width: 8.0),
                                        Text(
                                          'Masuk',
                                          style: GoogleFonts.arimo(
                                            fontSize: 14.0,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40.0),

                          // Footer: signup
                          SizedBox(
                            width: _cardWidth,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Belum punya akun?',
                                  style: GoogleFonts.arimo(
                                    fontSize: 16.0,
                                    color: const Color(0xFF4A3D5C),
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Daftar sekarang',
                                    style: GoogleFonts.arimo(
                                      fontSize: 16.0,
                                      color: const Color(0xFF8530E4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
