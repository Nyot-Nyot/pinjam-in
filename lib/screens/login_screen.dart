import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinjam_in/screens/home_screen.dart';
import 'package:pinjam_in/screens/register_screen.dart';
import 'package:pinjam_in/widgets/auth/auth_button.dart';
import 'package:pinjam_in/widgets/auth/auth_form_field.dart';
import 'package:pinjam_in/widgets/auth/auth_header.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/persistence_service.dart';
import '../services/shared_prefs_persistence.dart';
import '../services/supabase_persistence.dart';

// Use local SVG asset for button icon
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

      if (mounted) {
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Migrasi selesai. Data sekarang tersimpan di Supabase.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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
                          // Reusable auth header
                          const AuthHeader(
                            title: 'Selamat Datang',
                            subtitle: 'Masuk ke akun Anda',
                          ),

                          const SizedBox(height: 40.0),

                          // Form
                          SizedBox(
                            width: LoginScreen._cardWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Email field
                                AuthFormField(
                                  label: 'Email',
                                  hintText: 'nama@email.com',
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                ),

                                const SizedBox(height: 12.0),

                                // Password field
                                AuthFormField(
                                  label: 'Kata Sandi',
                                  hintText: 'Masukkan kata sandi',
                                  controller: _passwordController,
                                  obscureText: true,
                                ),

                                const SizedBox(height: 24.0),

                                // Button
                                AuthButton(
                                  text: 'Masuk',
                                  iconAsset: _enterIconAsset,
                                  isLoading: _isLoading,
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

                                    final email = _emailController.text.trim();
                                    final password = _passwordController.text;

                                    bool authSuccess = false;

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
                                            // ignore
                                          } else {
                                            rethrow;
                                          }
                                        }

                                        final client =
                                            (Supabase.instance.client);

                                        try {
                                          final res =
                                              await (client.auth as dynamic)
                                                  .signInWithPassword(
                                                    email: email,
                                                    password: password,
                                                  );
                                          final err =
                                              SupabasePersistence.authErrorFromResponse(
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
                                            final res =
                                                await (client.auth as dynamic)
                                                    .signIn(
                                                      email: email,
                                                      password: password,
                                                    );
                                            final err =
                                                SupabasePersistence.authErrorFromResponse(
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

                                    if (persistence is SupabasePersistence) {
                                      try {
                                        await _migrateLocalDataIfNeeded(
                                          persistence,
                                        );
                                      } catch (_) {}
                                    }

                                    if (!context.mounted) return;
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) => const HomeScreen(),
                                      ),
                                    );
                                  },
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
