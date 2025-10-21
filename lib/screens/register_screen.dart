import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_persistence.dart';

const String _logoAsset = 'assets/images/logo-purple.svg';
const String _enterIconAsset = 'assets/images/enter.svg';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  static const double _cardWidth = 329.6;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  String? _safeDotenv(String key) {
    try {
      if (dotenv.env.isEmpty) {
        try {
          dotenv.load(fileName: '.env');
        } catch (_) {}
      }
      final v = dotenv.env[key];
      if (v == null) return null;
      final trimmed = v.trim();
      if (trimmed.length >= 2 &&
          ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
              (trimmed.startsWith("'") && trimmed.endsWith("'")))) {
        return trimmed.substring(1, trimmed.length - 1);
      }
      return trimmed;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // use auth error helper from services/supabase_utils.dart

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

                          // Form fields
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
                                    decoration: InputDecoration.collapsed(
                                      hintText: 'Nama Anda',
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
                                    decoration: InputDecoration.collapsed(
                                      hintText: 'nama@email.com',
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
                                    decoration: InputDecoration.collapsed(
                                      hintText: 'Minimal 6 karakter',
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
                                      if (_isLoading) return;
                                      setState(() => _isLoading = true);

                                      final email = _emailController.text
                                          .trim();
                                      final password = _passwordController.text;

                                      final env = Platform.environment;
                                      final supabaseUrl =
                                          _safeDotenv('SUPABASE_URL') ??
                                          env['SUPABASE_URL'] ??
                                          const String.fromEnvironment(
                                            'SUPABASE_URL',
                                            defaultValue: '',
                                          );
                                      final supabaseKey =
                                          _safeDotenv('SUPABASE_ANON_KEY') ??
                                          env['SUPABASE_ANON_KEY'] ??
                                          const String.fromEnvironment(
                                            'SUPABASE_ANON_KEY',
                                            defaultValue: '',
                                          );

                                      bool created = false;

                                      if (supabaseUrl.isNotEmpty &&
                                          supabaseKey.isNotEmpty) {
                                        try {
                                          try {
                                            await Supabase.initialize(
                                              url: supabaseUrl,
                                              anonKey: supabaseKey,
                                            );
                                          } catch (e) {
                                            final s = e.toString();
                                            if (s.contains(
                                                  'already initialized',
                                                ) ||
                                                s.contains(
                                                  'already been initialized',
                                                ) ||
                                                s.contains(
                                                  'this instance is already initialized',
                                                )) {
                                              // ignore: supabase already initialized
                                            } else {
                                              rethrow;
                                            }
                                          }
                                          final client =
                                              Supabase.instance.client;
                                          try {
                                            final res =
                                                await (client.auth as dynamic)
                                                    .signUp(
                                                      email: email,
                                                      password: password,
                                                    );
                                            final err = SupabasePersistence
                                                .authErrorFromResponse(
                                              res,
                                            );
                                            if (err != null) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Daftar gagal: ${err.toString()}',
                                                    ),
                                                  ),
                                                );
                                              }
                                            } else {
                                              // Sign-up succeeded. Attempt to store the
                                              // user's display name into the `users` table
                                              // so other parts of the app can read it.
                                              var profileInserted = false;
                                              try {
                                                final name = _nameController
                                                    .text
                                                    .trim();
                                                if (name.isNotEmpty) {
                                                  final tbl =
                                                      (client as dynamic).from(
                                                        'users',
                                                      );
                                                  String? uid;
                                                  try {
                                                    final userObj =
                                                        (res as dynamic).user ??
                                                        (res as dynamic)
                                                            .data
                                                            ?.user;
                                                    uid =
                                                        userObj?.id as String?;
                                                  } catch (_) {}

                                                  final payload = {
                                                    if (uid != null) 'id': uid,
                                                    'email': _emailController
                                                        .text
                                                        .trim(),
                                                    'display_name': name,
                                                    'created_at': DateTime.now()
                                                        .toUtc()
                                                        .millisecondsSinceEpoch,
                                                  };

                                                  try {
                                                    await (tbl as dynamic)
                                                        .insert(payload);
                                                    profileInserted = true;
                                                  } catch (_) {
                                                    try {
                                                      await (tbl as dynamic)
                                                          .insert({
                                                            'email':
                                                                _emailController
                                                                    .text
                                                                    .trim(),
                                                            'display_name':
                                                                name,
                                                            'created_at':
                                                                DateTime.now()
                                                                    .toUtc()
                                                                    .millisecondsSinceEpoch,
                                                          });
                                                      profileInserted = true;
                                                    } catch (_) {
                                                      profileInserted = false;
                                                    }
                                                  }
                                                } else {
                                                  // nothing to write but treat as success
                                                  profileInserted = true;
                                                }
                                              } catch (_) {
                                                profileInserted = false;
                                              }

                                              created = true;
                                              // Provide user feedback about profile insert
                                              if (context.mounted) {
                                                if (profileInserted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Akun dibuat dan profil tersimpan',
                                                      ),
                                                    ),
                                                  );
                                                } else {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Akun dibuat, tetapi gagal menyimpan profil (silakan periksa koneksi).',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            }
                                          } catch (_) {
                                            try {
                                              final res =
                                                  await (client.auth as dynamic)
                                                      .signUp(
                                                        email: email,
                                                        password: password,
                                                      );
                                              final err = SupabasePersistence
                                                  .authErrorFromResponse(
                                                res,
                                              );
                                              if (err != null) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Daftar gagal: ${err.toString()}',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } else {
                                                created = true;
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Daftar error: $e',
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Supabase init failed: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      } else {
                                        // Supabase not configured: do NOT simulate success.
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Supabase belum dikonfigurasi. Tambahkan SUPABASE_URL dan SUPABASE_ANON_KEY di .env sebelum mendaftar.',
                                              ),
                                            ),
                                          );
                                        }
                                      }

                                      setState(() => _isLoading = false);

                                      if (!created) return;

                                      // Return the email to prefill login
                                      if (!context.mounted) return;
                                      Navigator.pop(context, email);
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
                                            colorFilter: const ColorFilter.mode(
                                              Colors.white,
                                              BlendMode.srcIn,
                                            ),
                                            fit: BoxFit.contain,
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
