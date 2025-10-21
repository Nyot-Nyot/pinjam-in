import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinjam_in/screens/home_screen.dart';
import 'package:pinjam_in/screens/register_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/persistence_service.dart';
import '../services/shared_prefs_persistence.dart';
import '../services/supabase_persistence.dart';
import '../services/supabase_utils.dart';

// Use local SVG assets placed under assets/images/
const String _logoAsset = 'assets/images/logo-purple.svg';
const String _enterIconAsset = 'assets/images/enter.svg';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const double _cardWidth = 329.6;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // Safely read from dotenv; flutter_dotenv throws if not initialized.
  Future<String?> _safeDotenv(String key) async {
    try {
      // If dotenv wasn't loaded in main for some reason, try to load it lazily.
      if (dotenv.env.isEmpty) {
        try {
          await dotenv.load(fileName: '.env');
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _migrateLocalDataIfNeeded(SupabasePersistence supa) async {
    try {
      // Load local data
      final local = SharedPrefsPersistence();
      final localActive = await local.loadActive();
      final localHistory = await local.loadHistory();

      if (localActive.isEmpty && localHistory.isEmpty) return;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Migrating local data to Supabase...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Upsert into Supabase
      await supa.saveAll(active: localActive, history: localHistory);

      // Clear local storage after successful migration by overwriting with
      // empty lists via the existing SharedPrefsPersistence API.
      try {
        await local.saveActive([]);
        await local.saveHistory([]);
      } catch (_) {}

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Migrasi selesai. Data sekarang tersimpan di Supabase.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Migrasi gagal: $e')));
      }
    }
  }

  // use auth error helper from services/supabase_utils.dart

  Future<Map<String, dynamic>> _resolveSupabaseCredentials() async {
    final fromDotenvUrl = await _safeDotenv('SUPABASE_URL');
    final fromDotenvKey = await _safeDotenv('SUPABASE_ANON_KEY');

    final env = Platform.environment;
    final envUrl = env['SUPABASE_URL'];
    final envKey = env['SUPABASE_ANON_KEY'];

    final dartUrl = const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: '',
    );
    final dartKey = const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: '',
    );

    final url = (fromDotenvUrl != null && fromDotenvUrl.isNotEmpty)
        ? fromDotenvUrl
        : (envUrl != null && envUrl.isNotEmpty)
        ? envUrl
        : (dartUrl.isNotEmpty ? dartUrl : '');

    final key = (fromDotenvKey != null && fromDotenvKey.isNotEmpty)
        ? fromDotenvKey
        : (envKey != null && envKey.isNotEmpty)
        ? envKey
        : (dartKey.isNotEmpty ? dartKey : '');

    return {
      'url': url,
      'key': key,
      'fromDotenvUrl': fromDotenvUrl != null && fromDotenvUrl.isNotEmpty,
      'fromDotenvKey': fromDotenvKey != null && fromDotenvKey.isNotEmpty,
      'fromEnvUrl': envUrl != null && envUrl.isNotEmpty,
      'fromEnvKey': envKey != null && envKey.isNotEmpty,
      'fromDartUrl': dartUrl.isNotEmpty,
      'fromDartKey': dartKey.isNotEmpty,
    };
  }

  String _mask(String? v, {int head = 8, int tail = 6}) {
    if (v == null || v.isEmpty) return '<empty>';
    if (v.length <= head + tail) return '${v.substring(0, 4)}...';
    return '${v.substring(0, head)}...${v.substring(v.length - tail)}';
  }

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
                      constraints: BoxConstraints(
                        maxWidth: LoginScreen._cardWidth,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Top container with icon and headings
                          SizedBox(
                            width: LoginScreen._cardWidth,
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
                            width: LoginScreen._cardWidth,
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
                                      child: TextField(
                                        controller: _emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
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
                                      child: TextField(
                                        controller: _passwordController,
                                        obscureText: true,
                                        decoration: InputDecoration.collapsed(
                                          hintText: 'Masukkan kata sandi',
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

                                      PersistenceService persistence =
                                          SharedPrefsPersistence();

                                      // Resolve credentials (await so dotenv load completes)
                                      final diag =
                                          await _resolveSupabaseCredentials();
                                      final supabaseUrl = diag['url'] as String;
                                      final supabaseKey = diag['key'] as String;

                                      if (supabaseUrl.isEmpty ||
                                          supabaseKey.isEmpty) {
                                        if (context.mounted) {
                                          final partial =
                                              'url=${_mask(supabaseUrl)} key=${_mask(supabaseKey)}';
                                          final sources =
                                              'dotenv:${diag['fromDotenvUrl']}/${diag['fromDotenvKey']} env:${diag['fromEnvUrl']}/${diag['fromEnvKey']} dart-define:${diag['fromDartUrl']}/${diag['fromDartKey']}';
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Supabase credentials missing or empty. $partial; sources: $sources',
                                              ),
                                              duration: const Duration(
                                                seconds: 6,
                                              ),
                                            ),
                                          );
                                        }
                                      } else {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Using Supabase: ${_mask(supabaseUrl)}',
                                              ),
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        }
                                      }

                                      final email = _emailController.text
                                          .trim();
                                      final password = _passwordController.text;

                                      bool authSuccess = false;

                                      if (supabaseUrl.isNotEmpty &&
                                          supabaseKey.isNotEmpty) {
                                        try {
                                          // If Supabase wasn't already initialized by
                                          // main.dart, attempt to initialize it here.
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
                                              // ignore
                                            } else {
                                              rethrow;
                                            }
                                          }

                                          final client =
                                              (Supabase.instance.client);

                                          // attempt sign-in using multiple possible APIs
                                          try {
                                            // newer API
                                            final res =
                                                await (client.auth as dynamic)
                                                    .signInWithPassword(
                                                      email: email,
                                                      password: password,
                                                    );
                                            final err = authErrorFromResponse(
                                              res,
                                            );
                                            if (err != null) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Login gagal: ${err.toString()}',
                                                    ),
                                                  ),
                                                );
                                              }
                                            } else {
                                              authSuccess = true;
                                              persistence =
                                                  SupabasePersistence.fromClient(
                                                    client,
                                                  );
                                            }
                                          } catch (_) {
                                            try {
                                              // older API
                                              final res =
                                                  await (client.auth as dynamic)
                                                      .signIn(
                                                        email: email,
                                                        password: password,
                                                      );
                                              final err = authErrorFromResponse(
                                                res,
                                              );
                                              if (err != null) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Login gagal: ${err.toString()}',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } else {
                                                authSuccess = true;
                                                persistence =
                                                    SupabasePersistence.fromClient(
                                                      client,
                                                    );
                                              }
                                            } catch (e) {
                                              // unknown error
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Login error: $e',
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        } catch (e) {
                                          // initialization error
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
                                        // Supabase not configured: do NOT auto-succeed.
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Supabase belum dikonfigurasi. Harap tambahkan SUPABASE_URL dan SUPABASE_ANON_KEY di .env',
                                              ),
                                            ),
                                          );
                                        }
                                      }

                                      setState(() => _isLoading = false);

                                      if (!authSuccess) return;

                                      // If we're using Supabase persistence, attempt to
                                      // migrate any local SharedPrefs data to Supabase
                                      if (persistence is SupabasePersistence) {
                                        try {
                                          await _migrateLocalDataIfNeeded(
                                            persistence,
                                          );
                                        } catch (_) {}
                                      }

                                      // Navigate to Home with chosen persistence
                                      if (!context.mounted) return;
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                          builder: (_) => HomeScreen(
                                            persistence: persistence,
                                          ),
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
                                            colorFilter: const ColorFilter.mode(
                                              Colors.white,
                                              BlendMode.srcIn,
                                            ),
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
                            width: LoginScreen._cardWidth,
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
