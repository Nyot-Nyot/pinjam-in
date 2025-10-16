import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

const String _logoAsset = 'assets/images/logo-purple.svg';
const String _enterIconAsset = 'assets/images/enter.svg';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  static const double _cardWidth = 329.6;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6EFFD),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: RegisterScreen._cardWidth,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Top icon and headings
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

                          Text(
                            'Buat Akun',
                            style: GoogleFonts.arimo(
                              fontSize: 16.0,
                              color: const Color(0xFF8530E4),
                            ),
                          ),

                          const SizedBox(height: 8.0),

                          SizedBox(
                            width: 250.317,
                            child: Text(
                              'Daftar untuk mulai menggunakan',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.arimo(
                                fontSize: 16.0,
                                color: const Color(0xFF4A3D5C),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40.0),

                          // Form fields (interactive)
                          SizedBox(
                            width: RegisterScreen._cardWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Nama Lengkap
                                Text(
                                  'Nama Lengkap',
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
                                    controller: _nameController,
                                    decoration: const InputDecoration.collapsed(
                                      hintText: 'Nama Anda',
                                    ),
                                    style: GoogleFonts.arimo(
                                      fontSize: 16.0,
                                      color: const Color(0xFF4A3D5C),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12.0),

                                // Email
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
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration.collapsed(
                                      hintText: 'nama@email.com',
                                    ),
                                    style: GoogleFonts.arimo(
                                      fontSize: 16.0,
                                      color: const Color(0xFF4A3D5C),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12.0),

                                // Password
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
                                    controller: _passwordController,
                                    obscureText: true,
                                    decoration: const InputDecoration.collapsed(
                                      hintText: 'Minimal 6 karakter',
                                    ),
                                    style: GoogleFonts.arimo(
                                      fontSize: 16.0,
                                      color: const Color(0xFF4A3D5C),
                                    ),
                                  ),
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
                                    onPressed: () async {
                                      final useFirestore =
                                          kDebugMode &&
                                          Firebase.apps.isNotEmpty;

                                      final name = _nameController.text.trim();
                                      final email = _emailController.text
                                          .trim();
                                      final password = _passwordController.text;

                                      if (useFirestore) {
                                        final navigator = Navigator.of(context);
                                        final messenger = ScaffoldMessenger.of(
                                          context,
                                        );
                                        try {
                                          await FirebaseAuth.instance
                                              .createUserWithEmailAndPassword(
                                                email: email,
                                                password: password,
                                              );
                                          // Store profile in users collection
                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(email)
                                              .set({
                                                'displayName': name,
                                                'email': email,
                                                'createdAt':
                                                    FieldValue.serverTimestamp(),
                                              });
                                          if (!mounted) return;
                                          // Use captured messenger/navigator now that we're still mounted
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Akun berhasil dibuat di emulator',
                                              ),
                                            ),
                                          );
                                          navigator.pop();
                                        } catch (e) {
                                          // Reuse captured messenger to avoid using context across async gap
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text('Gagal daftar: $e'),
                                            ),
                                          );
                                        }
                                      } else {
                                        // On non-Firestore platforms, just go back to login
                                        Navigator.pop(context);
                                      }
                                    },
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 16.0,
                                          height: 16.0,
                                          child: SvgPicture.asset(
                                            _enterIconAsset,
                                            fit: BoxFit.contain,
                                            placeholderBuilder: (c) =>
                                                const SizedBox.shrink(),
                                          ),
                                        ),
                                        const SizedBox(width: 8.0),
                                        Text(
                                          'Buat Akun',
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

                          // Footer -> navigate back to login
                          SizedBox(
                            width: RegisterScreen._cardWidth,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Sudah punya akun?',
                                  style: GoogleFonts.arimo(
                                    fontSize: 16.0,
                                    color: const Color(0xFF4A3D5C),
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Text(
                                    'Masuk di sini',
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
