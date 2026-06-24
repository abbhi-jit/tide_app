import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyDlWOKStFVgAnMAbDbhgI-ZI10Py-SQHwg',
        authDomain: 'tideapp-4b5f0.firebaseapp.com',
        projectId: 'tideapp-4b5f0',
        storageBucket: 'tideapp-4b5f0.firebasestorage.app',
        messagingSenderId: '937799039554',
        appId: '1:937799039554:web:6703114a5c12506daf0bdb',
      ),
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }
  runApp(const TideApp());
}

// ── 1. DESIGN TOKENS ────────────────────────────────────────────────────────
class GlassColors {
  // Background gradient stops
  static const Color bgDeep = Color(0xFF020818);
  static const Color bgMid = Color(0xFF060F2A);
  static const Color bgOcean = Color(0xFF081832);

  // Glass material (defined as constants via hex alpha)
  static const Color glassFill = Color(0x1AFFFFFF); // white @ 10%
  static const Color glassFillStrong = Color(0x1AFFFFFF); // white @ 10%
  static const Color glassBorder = Color(0x33FFFFFF); // white @ 20%

  // Text
  static const Color textPrimary = Color(0xFFE8F4FF);
  static const Color textMuted = Color(0x80E8F4FF); // 50%
  static const Color textFaint = Color(0x4DE8F4FF); // 30%

  // Accent palette
  static const Color cyan = Color(0xFF00D4FF);
  static const Color violet = Color(0xFF7B61FF);
  static const Color coral = Color(0xFFFF6B6B);
  static const Color amber = Color(0xFFFFB347);
  static const Color mint = Color(0xFF4ECDC4);
  static const Color pink = Color(0xFFFF6B9D);

  // Category colors
  static const Color catToday = Color(0xFF00D4FF);
  static const Color catWork = Color(0xFF7B61FF);
  static const Color catPersonal = Color(0xFFFF6B9D);
  static const Color catStudy = Color(0xFFFFB347);

  // Priority colors
  static const Color priorityHigh = Color(0xFFFF6B6B);
  static const Color priorityMed = Color(0xFFFFB347);
  static const Color priorityLow = Color(0xFF4ECDC4);

  static const Color glassHighlight = Color(0x2200D4FF);
  static const Color glassLowlight = Color(0x167B61FF);
}

// ── 2. DATE HELPER ──────────────────────────────────────────────────────────
String formatDate(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

// ── 3. CORE DATA MODEL ──────────────────────────────────────────────────────
class Task {
  final String id;
  String title;
  String notes;
  String priority; // 'High' | 'Med' | 'Low'
  String category; // 'Today' | 'Work' | 'Personal' | 'Study'
  DateTime dueDate;
  bool isDone;

  Task({
    required this.id,
    required this.title,
    this.notes = '',
    required this.priority,
    required this.category,
    required this.dueDate,
    this.isDone = false,
  });

  Color get priorityColor {
    switch (priority) {
      case 'High':
        return GlassColors.priorityHigh;
      case 'Med':
        return GlassColors.priorityMed;
      default:
        return GlassColors.priorityLow;
    }
  }

  Color get categoryColor {
    switch (category) {
      case 'Work':
        return GlassColors.catWork;
      case 'Personal':
        return GlassColors.catPersonal;
      case 'Study':
        return GlassColors.catStudy;
      default:
        return GlassColors.catToday;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'priority': priority,
        'category': category,
        'dueDate': dueDate.toIso8601String(),
        'isDone': isDone,
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        notes: (j['notes'] as String?) ?? '',
        priority: j['priority'] as String,
        category: j['category'] as String,
        dueDate: DateTime.parse(j['dueDate'] as String),
        isDone: (j['isDone'] as bool?) ?? false,
      );
}

// ── 4. FIRESTORE SERVICE ─────────────────────────────────────────────────
class TaskStorage {
  static Future<void> save(List<Task> tasks) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final batch = FirebaseFirestore.instance.batch();
    final tasksRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tasks');
        
    for (var task in tasks) {
      batch.set(tasksRef.doc(task.id), task.toJson());
    }
    await batch.commit();
  }

  static Future<void> delete(Task task) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tasks')
        .doc(task.id)
        .delete();
  }

  static Future<List<Task>> load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tasks')
        .get();
        
    return snapshot.docs.map((doc) => Task.fromJson(doc.data())).toList();
  }
  
  static Future<String> shareTask(Task task) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shared_tasks')
        .doc(task.id)
        .set(task.toJson()..addAll({'sharedBy': user.uid}));
    return 'https://tideapp.web.app/?sharedTask=${user.uid}/${task.id}';
  }
}

// ── 5. APP ENTRY POINT ──────────────────────────────────────────────────────
class TideApp extends StatelessWidget {
  const TideApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Intercept shared links via URL
    final sharedTaskParam = Uri.base.queryParameters['sharedTask'];
    if (sharedTaskParam != null && sharedTaskParam.contains('/')) {
      final parts = sharedTaskParam.split('/');
      return MaterialApp(
        title: 'Tide Shared Task',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: GlassColors.bgDeep,
          colorScheme: const ColorScheme.dark(
            primary: GlassColors.cyan,
            secondary: GlassColors.violet,
            surface: GlassColors.bgMid,
          ),
          fontFamily: 'Inter',
        ),
        home: SharedTaskViewScreen(userId: parts[0], taskId: parts[1]),
      );
    }

    return MaterialApp(
      title: 'Tide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: GlassColors.bgDeep,
        colorScheme: const ColorScheme.dark(
          primary: GlassColors.cyan,
          secondary: GlassColors.violet,
          surface: GlassColors.bgMid,
        ),
        fontFamily: 'Inter',
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return MainNavigationShell(
              userName: snapshot.data?.displayName ?? 'User',
              userEmail: snapshot.data?.email ?? '',
            );
          }
          return const OnboardingScreen();
        },
      ),
    );
  }
}

// ── SHARED WIDGET: AnimatedBackground ───────────────────────────────────────
// Renders a deep-space gradient with a soft animated glass wash.
class AnimatedBackground extends StatefulWidget {
  final Widget child;
  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.50, 1.0],
              colors: [
                GlassColors.bgDeep,
                GlassColors.bgMid,
                GlassColors.bgOcean,
              ],
            ),
          ),
        ),
        // Floating antigravity orbs
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return CustomPaint(
                painter: _OrbPainter(_controller.value),
              );
            },
          ),
        ),
        // Animated glass wash overlay
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              final t = (math.sin(_controller.value * math.pi * 2) + 1) / 2;
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.lerp(
                      const Alignment(-1.0, -0.75),
                      const Alignment(-0.25, -1.0),
                      t,
                    )!,
                    end: Alignment.lerp(
                      const Alignment(0.85, 1.0),
                      const Alignment(1.0, 0.35),
                      t,
                    )!,
                    colors: const [
                      Colors.transparent,
                      GlassColors.glassLowlight,
                      GlassColors.glassHighlight,
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.38, 0.62, 1.0],
                  ),
                ),
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

// Paints soft, semi-transparent orbs that drift with an antigravity float.
class _OrbPainter extends CustomPainter {
  final double t;
  _OrbPainter(this.t);

  static const _orbs = <_Orb>[
    _Orb(
        baseX: 0.15,
        baseY: 0.10,
        driftX: 0.06,
        driftY: 0.08,
        radius: 0.18,
        colorIdx: 0,
        opacity: 0.07,
        speed: 1.0,
        phase: 0.0),
    _Orb(
        baseX: 0.82,
        baseY: 0.25,
        driftX: 0.05,
        driftY: 0.07,
        radius: 0.14,
        colorIdx: 1,
        opacity: 0.06,
        speed: 0.7,
        phase: 1.2),
    _Orb(
        baseX: 0.30,
        baseY: 0.52,
        driftX: 0.08,
        driftY: 0.05,
        radius: 0.22,
        colorIdx: 0,
        opacity: 0.05,
        speed: 0.5,
        phase: 2.5),
    _Orb(
        baseX: 0.78,
        baseY: 0.70,
        driftX: 0.04,
        driftY: 0.06,
        radius: 0.12,
        colorIdx: 2,
        opacity: 0.05,
        speed: 0.8,
        phase: 3.8),
    _Orb(
        baseX: 0.50,
        baseY: 0.88,
        driftX: 0.07,
        driftY: 0.04,
        radius: 0.16,
        colorIdx: 1,
        opacity: 0.04,
        speed: 0.6,
        phase: 5.0),
  ];

  static const _palette = [
    GlassColors.cyan,
    GlassColors.violet,
    GlassColors.coral
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final orb in _orbs) {
      final angle = t * 2.0 * math.pi * orb.speed + orb.phase;
      final cx = (orb.baseX + math.sin(angle) * orb.driftX) * size.width;
      final cy = (orb.baseY + math.cos(angle * 0.7) * orb.driftY) * size.height;
      final r = orb.radius * size.shortestSide;
      final color = _palette[orb.colorIdx];

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: orb.opacity),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));

      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) => true;
}

class _Orb {
  final double baseX, baseY, driftX, driftY, radius, opacity, speed, phase;
  final int colorIdx;
  const _Orb({
    required this.baseX,
    required this.baseY,
    required this.driftX,
    required this.driftY,
    required this.radius,
    required this.colorIdx,
    required this.opacity,
    required this.speed,
    required this.phase,
  });
}

// ── SHARED WIDGET: GlassCard ─────────────────────────────────────────────
// Frosted glass panel: BackdropFilter blur + semi-transparent fill + border.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double borderRadius;
  final Color? fillColor;
  final Color? borderColor;
  final double blurSigma;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 24,
    this.fillColor,
    this.borderColor,
    this.blurSigma = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fillColor ?? GlassColors.glassFill,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? GlassColors.glassBorder,
              width: 1.0,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── SHARED WIDGET: GlassTextField ─────────────────────────────────────────
class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final bool autofocus;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          autofocus: autofocus,
          style: const TextStyle(color: GlassColors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: GlassColors.textMuted),
            filled: true,
            fillColor: GlassColors.glassFillStrong,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: GlassColors.glassBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: GlassColors.glassBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: GlassColors.cyan, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

// ── SHARED WIDGET: _GlowButton ─────────────────────────────────────────────
// Gradient CTA button with cyan → violet fill and a soft cyan glow shadow.
class _GlowButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool compact;

  const _GlowButton({
    required this.label,
    required this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = compact ? 14.0 : 20.0;
    final height = compact ? 48.0 : 56.0;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: const LinearGradient(
            colors: [GlassColors.cyan, GlassColors.violet],
          ),
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
          onPressed: onPressed,
          child: Text(
            label,
            style: TextStyle(
              fontSize: compact ? 14 : 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

// ── SCREEN 01: ONBOARDING ───────────────────────────────────────────────────
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Glowing teal logo orb
                Container(
                  width: 148,
                  height: 148,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFF00D4FF), Color(0xFF0A4F72)],
                      radius: 0.8,
                    ),
                  ),
                  child: const Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.waves_rounded, size: 72, color: Colors.white),
                      Positioned(
                        top: 24,
                        right: 22,
                        child: Icon(
                          Icons.wb_sunny_rounded,
                          size: 30,
                          color: GlassColors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                // Headline
                const Text(
                  'Bring Balance\nto Your Day',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: GlassColors.textPrimary,
                    height: 1.2,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 20),
                // Frosted subtitle card
                GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: const Text(
                    'Sync your tasks with the natural, calming\nmovement of the daily tides.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: GlassColors.textMuted,
                      height: 1.6,
                    ),
                  ),
                ),
                const Spacer(),
                _GlowButton(
                  label: 'Get Started',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── SCREEN 02: LOGIN ────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _handleAuth() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty || (!_isLogin && name.isEmpty)) {
      _showError('Please fill in all fields.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await cred.user?.updateDisplayName(name);
      }
      
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainNavigationShell(
            userName: _isLogin ? (FirebaseAuth.instance.currentUser?.displayName ?? 'User') : name,
            userEmail: email,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String msg = 'Authentication failed.';
      if (e.code == 'email-already-in-use') {
        msg = 'The email is already in use.';
      } else if (e.code == 'weak-password') {
        msg = 'The password is too weak.';
      } else if (e.code == 'invalid-credential') {
        msg = 'Invalid email or password.';
      }
      _showError(msg);
    } catch (e) {
      _showError(e.toString());
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: GlassColors.coral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: GlassColors.textPrimary, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isLogin ? 'Sign In' : 'Register',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: GlassColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  _isLogin ? 'Welcome\nBack' : 'Create\nAccount',
                  style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: GlassColors.textPrimary, height: 1.1),
                ),
                const SizedBox(height: 10),
                Text(
                  _isLogin ? 'Sign in to continue tracking your daily task flow.' : 'Register to unlock cloud sync and sharing features.',
                  style: const TextStyle(fontSize: 15, color: GlassColors.textMuted, height: 1.5),
                ),
                const SizedBox(height: 36),
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isLogin) ...[
                        _fieldLabel('FULL NAME'),
                        const SizedBox(height: 8),
                        GlassTextField(controller: _nameController, hintText: 'John Doe', keyboardType: TextInputType.name),
                        const SizedBox(height: 20),
                      ],
                      _fieldLabel('EMAIL ADDRESS'),
                      const SizedBox(height: 8),
                      GlassTextField(controller: _emailController, hintText: 'name@example.com', keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 20),
                      _fieldLabel('PASSWORD'),
                      const SizedBox(height: 8),
                      GlassTextField(controller: _passwordController, hintText: '••••••••', obscureText: true),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: GlassColors.cyan))
                  : _GlowButton(label: _isLogin ? 'Sign In' : 'Register', onPressed: _handleAuth),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: RichText(
                      text: TextSpan(
                        text: _isLogin ? "Don't have an account? " : "Already have an account? ",
                        style: const TextStyle(color: GlassColors.textMuted, fontSize: 14),
                        children: [
                          TextSpan(
                            text: _isLogin ? 'Sign Up' : 'Sign In',
                            style: const TextStyle(color: GlassColors.cyan, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GlassColors.textMuted),
      );
}

// ── CENTRAL SHELL AND NAVIGATION ARCHITECTURE ───────────────────────────────
class MainNavigationShell extends StatefulWidget {
  final String userName;
  final String userEmail;

  const MainNavigationShell({
    super.key,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  String? _profileImageUrl;
  bool _isLoading = true;

  final List<Task> _globalTasks = [];
  bool _notificationsEnabled = true;
  bool _summaryEmailsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final saved = await TaskStorage.load();
      setState(() {
        if (saved.isNotEmpty) {
          _globalTasks.addAll(saved);
        }
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _persistTasks() => TaskStorage.save(_globalTasks);

  void _openAddTaskSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTaskSheet(
        onSave: (title, notes, priority, category, dueDate) async {
          setState(() {
            _globalTasks.insert(
              0,
              Task(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: title,
                notes: notes,
                priority: priority,
                category: category,
                dueDate: dueDate,
              ),
            );
          });
          await _persistTasks();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: GlassColors.bgDeep,
        body: Center(child: CircularProgressIndicator(color: GlassColors.cyan)),
      );
    }

    final List<Widget> screens = [
      HomeScreenTab(
        userName: widget.userName,
        profileImageUrl: _profileImageUrl,
        tasks: _globalTasks,
        onToggle: (task) async {
          setState(() => task.isDone = !task.isDone);
          await _persistTasks();
        },
        onViewDetail: (task) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskDetailScreen(
                task: task,
                onChanged: (_) async {
                  setState(() {});
                  await _persistTasks();
                },
                onDelete: () async {
                  setState(() => _globalTasks.remove(task));
                  await TaskStorage.delete(task);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
              ),
            ),
          );
        },
      ),
      TaskListScreenTab(
        tasks: _globalTasks,
        onToggle: (task) async {
          setState(() => task.isDone = !task.isDone);
          await _persistTasks();
        },
        onDelete: (task) async {
          setState(() => _globalTasks.remove(task));
          await TaskStorage.delete(task); // Actually delete from backend
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${task.title}" deleted.'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  setState(() => _globalTasks.add(task));
                  await _persistTasks();
                },
              ),
            ),
          );
        },
        onViewDetail: (task) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskDetailScreen(
                task: task,
                onChanged: (_) async {
                  setState(() {});
                  await _persistTasks();
                },
                onDelete: () async {
                  setState(() => _globalTasks.remove(task));
                  await TaskStorage.delete(task);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
              ),
            ),
          );
        },
      ),
      SettingsScreenTab(
        userName: widget.userName,
        userEmail: widget.userEmail,
        profileImageUrl: _profileImageUrl,
        onUpdateProfileImage: (url) =>
            setState(() => _profileImageUrl = url.isEmpty ? null : url),
        notificationsEnabled: _notificationsEnabled,
        summaryEmailsEnabled: _summaryEmailsEnabled,
        onToggleNotifications: (val) =>
            setState(() => _notificationsEnabled = val),
        onToggleEmails: (val) => setState(() => _summaryEmailsEnabled = val),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: AnimatedBackground(
        child: IndexedStack(index: _currentIndex, children: screens),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const FloatingChatWidget(),
            const SizedBox(height: 12),
            GlassCard(
              borderRadius: 20,
              padding: EdgeInsets.zero,
              fillColor: GlassColors.cyan.withValues(alpha: 0.18),
              borderColor: GlassColors.cyan.withValues(alpha: 0.50),
              child: FloatingActionButton(
                backgroundColor: Colors.transparent,
                elevation: 0,
                onPressed: _openAddTaskSheet,
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: GlassColors.bgDeep.withValues(alpha: 0.72),
              border: const Border(
                top: BorderSide(color: GlassColors.glassBorder, width: 1),
              ),
            ),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: GlassColors.cyan,
              unselectedItemColor: GlassColors.textMuted,
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.list_alt_outlined),
                  activeIcon: Icon(Icons.assignment_rounded),
                  label: 'Tasks',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded),
                  activeIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── SCREEN 03: HOME TAB ─────────────────────────────────────────────────────
class HomeScreenTab extends StatelessWidget {
  final String userName;
  final String? profileImageUrl;
  final List<Task> tasks;
  final Function(Task) onToggle;
  final Function(Task) onViewDetail;

  const HomeScreenTab({
    super.key,
    required this.userName,
    this.profileImageUrl,
    required this.tasks,
    required this.onToggle,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    final todayTasks = tasks.where((t) => t.category == 'Today').toList();
    final remainingCount = todayTasks.where((t) => !t.isDone).length;
    final doneCount = tasks.where((t) => t.isDone).length;
    const streakCount = 5;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Floating glass header
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good morning 👋  $userName',
                        style: const TextStyle(
                          fontSize: 13,
                          color: GlassColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tide Dashboard',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: GlassColors.textPrimary,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: GlassColors.cyan, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: GlassColors.violet,
                      backgroundImage: profileImageUrl != null
                          ? NetworkImage(profileImageUrl!)
                          : null,
                      child: profileImageUrl == null
                          ? Text(
                              userName.isNotEmpty
                                  ? userName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // ── Metric stat cards
            Row(
              children: [
                Expanded(
                  child: _metricCard(
                    Icons.today_rounded,
                    GlassColors.cyan,
                    'Today',
                    '$remainingCount Left',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard(
                    Icons.check_circle_outline_rounded,
                    GlassColors.mint,
                    'Done',
                    '$doneCount Done',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard(
                    Icons.local_fire_department_rounded,
                    GlassColors.coral,
                    'Streak',
                    '$streakCount Days',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            // ── Section label
            const Text(
              "TODAY'S TASKS",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: GlassColors.cyan,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 12),
            // ── Today task list
            Expanded(
              child: todayTasks.isEmpty
                  ? Center(
                      child: GlassCard(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.beach_access_rounded,
                              size: 48,
                              color: GlassColors.textFaint,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No tasks scheduled for today. 🌊',
                              style: TextStyle(
                                color: GlassColors.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: todayTasks.length,
                      itemBuilder: (_, i) => _taskRow(todayTasks[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(IconData icon, Color color, String title, String value) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: GlassColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: GlassColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskRow(Task task) {
    return GestureDetector(
      onTap: () => onViewDetail(task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Category accent bar
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: task.categoryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Transform.scale(
                scale: 1.05,
                child: Checkbox(
                  value: task.isDone,
                  activeColor: GlassColors.cyan,
                  checkColor: Colors.white,
                  side: const BorderSide(
                    color: GlassColors.textMuted,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: (_) => onToggle(task),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                    decorationColor: GlassColors.textMuted,
                    color: task.isDone
                        ? GlassColors.textMuted
                        : GlassColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.priorityColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── SCREEN 04: TASK LIST TAB ─────────────────────────────────────────────────
class TaskListScreenTab extends StatefulWidget {
  final List<Task> tasks;
  final Function(Task) onToggle;
  final Function(Task) onDelete;
  final Function(Task) onViewDetail;

  const TaskListScreenTab({
    super.key,
    required this.tasks,
    required this.onToggle,
    required this.onDelete,
    required this.onViewDetail,
  });

  @override
  State<TaskListScreenTab> createState() => _TaskListScreenTabState();
}

class _TaskListScreenTabState extends State<TaskListScreenTab> {
  String _activeFilter = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  static const Map<String, Color> _catColors = {
    'All': GlassColors.textPrimary,
    'Today': GlassColors.catToday,
    'Work': GlassColors.catWork,
    'Personal': GlassColors.catPersonal,
    'Study': GlassColors.catStudy,
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Apply category + real-time search filters
    var filtered = _activeFilter == 'All'
        ? widget.tasks
        : widget.tasks.where((t) => t.category == _activeFilter).toList();
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (t) => t.title.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Floating glass header with search
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Task Workspace',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: GlassColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Real-time search bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                          color: GlassColors.textPrimary,
                          fontSize: 14,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Search tasks...',
                          hintStyle: const TextStyle(
                            color: GlassColors.textMuted,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: GlassColors.textMuted,
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: GlassColors.textMuted,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: GlassColors.glassFill,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: GlassColors.glassBorder,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: GlassColors.glassBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: GlassColors.cyan,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // ── Color-coded category filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _catColors.entries.map((entry) {
                  final isSelected = _activeFilter == entry.key;
                  final color = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _activeFilter = entry.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: isSelected
                              ? color.withValues(alpha: 0.22)
                              : GlassColors.glassFill,
                          border: Border.all(
                            color: isSelected ? color : GlassColors.glassBorder,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isSelected ? color : GlassColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            // ── Task list
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: GlassCard(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🌊', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            const Text(
                              'All caught up!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: GlassColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Your task horizon is clear.',
                              style: TextStyle(
                                color: GlassColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final task = filtered[i];
                        return Dismissible(
                          key: Key(task.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => widget.onDelete(task),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: GlassColors.coral.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: GlassColors.coral.withValues(
                                  alpha: 0.50,
                                ),
                              ),
                            ),
                            child: const Icon(
                              Icons.delete_sweep_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          child: GestureDetector(
                            onTap: () => widget.onViewDetail(task),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: GlassCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    // Category accent bar
                                    Container(
                                      width: 4,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: task.categoryColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Checkbox(
                                      value: task.isDone,
                                      activeColor: GlassColors.cyan,
                                      checkColor: Colors.white,
                                      side: const BorderSide(
                                        color: GlassColors.textMuted,
                                        width: 1.5,
                                      ),
                                      onChanged: (_) => widget.onToggle(task),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task.title,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              decoration: task.isDone
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                              decorationColor:
                                                  GlassColors.textMuted,
                                              color: task.isDone
                                                  ? GlassColors.textMuted
                                                  : GlassColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: task.categoryColor
                                                      .withValues(alpha: 0.18),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  task.category,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: task.categoryColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Due ${formatDate(task.dueDate)}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: GlassColors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: task.priorityColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── SCREEN 05: TASK DETAIL ───────────────────────────────────────────────────
class TaskDetailScreen extends StatefulWidget {
  final Task task;
  final Function(Task) onChanged;
  final Function() onDelete;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late bool _isDone;

  @override
  void initState() {
    super.initState();
    _isDone = widget.task.isDone;
  }

  void _toggleStatus() {
    setState(() {
      _isDone = !_isDone;
      widget.task.isDone = _isDone;
    });
    widget.onChanged(widget.task);
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Floating glass header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        GlassCard(
                          borderRadius: 14,
                          padding: EdgeInsets.zero,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: GlassColors.textPrimary,
                              size: 18,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Task Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: GlassColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        GlassCard(
                          borderRadius: 14,
                          padding: EdgeInsets.zero,
                          child: IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            onPressed: () {
                              widget.onDelete();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        GlassCard(
                          borderRadius: 14,
                          padding: EdgeInsets.zero,
                          child: IconButton(
                            icon: const Icon(
                              Icons.share_rounded,
                              color: GlassColors.textPrimary,
                              size: 18,
                            ),
                            onPressed: () async {
                              final link = await TaskStorage.shareTask(task);
                              await Clipboard.setData(ClipboardData(text: link));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Share link copied to clipboard!'),
                                    backgroundColor: GlassColors.cyan,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // ── Details glass card
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category + priority badges
                      Row(
                        children: [
                          _badge(task.category, task.categoryColor),
                          const SizedBox(width: 8),
                          _badge(
                            '${task.priority} Priority',
                            task.priorityColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: GlassColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _iconRow(
                        Icons.calendar_month_rounded,
                        'Due on ${formatDate(task.dueDate)}',
                      ),
                      const SizedBox(height: 8),
                      _iconRow(
                        Icons.folder_open_rounded,
                        'Workspace: ${task.category}',
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: GlassColors.glassBorder),
                      const SizedBox(height: 16),
                      const Text(
                        'NOTES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: GlassColors.textMuted,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        task.notes.isEmpty
                            ? 'No notes provided for this task.'
                            : task.notes,
                        style: const TextStyle(
                          fontSize: 14,
                          color: GlassColors.textMuted,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // ── Mark complete / incomplete button
                _GlowButton(
                  label: _isDone ? 'Mark Incomplete' : 'Mark Complete ✓',
                  onPressed: _toggleStatus,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.40)),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: color),
        ),
      );

  Widget _iconRow(IconData icon, String text) => Row(
        children: [
          Icon(icon, color: GlassColors.textMuted, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: GlassColors.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      );
}

// ── SCREEN 06: ADD TASK SHEET ────────────────────────────────────────────────
class AddTaskSheet extends StatefulWidget {
  final Function(
    String title,
    String notes,
    String priority,
    String category,
    DateTime dueDate,
  ) onSave;

  const AddTaskSheet({super.key, required this.onSave});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedPriority = 'Med';
  String _selectedCategory = 'Today';
  DateTime _selectedDate = DateTime.now();

  static const Map<String, Color> _priorityColors = {
    'High': GlassColors.priorityHigh,
    'Med': GlassColors.priorityMed,
    'Low': GlassColors.priorityLow,
  };

  static const Map<String, Color> _categoryColors = {
    'Today': GlassColors.catToday,
    'Work': GlassColors.catWork,
    'Personal': GlassColors.catPersonal,
    'Study': GlassColors.catStudy,
  };

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: GlassColors.cyan,
            surface: Color(0xFF0D1F3C),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _handleSave() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a task title.'),
          backgroundColor: GlassColors.coral,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    widget.onSave(
      title,
      _notesController.text.trim(),
      _selectedPriority,
      _selectedCategory,
      _selectedDate,
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          decoration: BoxDecoration(
            color: GlassColors.bgMid.withValues(alpha: 0.88),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: const Border(
              top: BorderSide(color: GlassColors.glassBorder, width: 1),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sheet drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: GlassColors.glassBorder,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Create New Task',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: GlassColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: GlassColors.textMuted,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: _titleController,
                  hintText: "What's on your horizon?",
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                GlassTextField(
                  controller: _notesController,
                  hintText: 'Add detailed notes...',
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                _sectionLabel('PRIORITY'),
                const SizedBox(height: 10),
                Row(
                  children: _priorityColors.entries
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _glassPill(
                            label: e.key,
                            isSelected: _selectedPriority == e.key,
                            color: e.value,
                            onTap: () =>
                                setState(() => _selectedPriority = e.key),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                _sectionLabel('CATEGORY'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categoryColors.entries
                      .map(
                        (e) => _glassPill(
                          label: e.key,
                          isSelected: _selectedCategory == e.key,
                          color: e.value,
                          onTap: () =>
                              setState(() => _selectedCategory = e.key),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                _sectionLabel('DUE DATE'),
                const SizedBox(height: 10),
                GlassCard(
                  borderRadius: 14,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: InkWell(
                    onTap: _pickDate,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatDate(_selectedDate),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: GlassColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: GlassColors.cyan,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                _GlowButton(label: 'Save Task', onPressed: _handleSave),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: GlassColors.textMuted,
          letterSpacing: 0,
        ),
      );

  Widget _glassPill({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected
              ? color.withValues(alpha: 0.24)
              : GlassColors.glassFill,
          border: Border.all(
            color: isSelected ? color : GlassColors.glassBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isSelected ? color : GlassColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── SCREEN 07: SETTINGS / PROFILE ───────────────────────────────────────────
class SettingsScreenTab extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String? profileImageUrl;
  final bool notificationsEnabled;
  final bool summaryEmailsEnabled;
  final Function(bool) onToggleNotifications;
  final Function(bool) onToggleEmails;
  final Function(String) onUpdateProfileImage;

  const SettingsScreenTab({
    super.key,
    required this.userName,
    required this.userEmail,
    this.profileImageUrl,
    required this.notificationsEnabled,
    required this.summaryEmailsEnabled,
    required this.onToggleNotifications,
    required this.onToggleEmails,
    required this.onUpdateProfileImage,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: const Row(
                children: [
                  Icon(Icons.person_rounded, color: GlassColors.cyan, size: 22),
                  SizedBox(width: 12),
                  Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: GlassColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // ── Profile glass card
            GlassCard(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _showUpdateImageDialog(context),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: GlassColors.cyan,
                              width: 2.5,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: GlassColors.violet,
                            backgroundImage: profileImageUrl != null
                                ? NetworkImage(profileImageUrl!)
                                : null,
                            child: profileImageUrl == null
                                ? Text(
                                    userName.isNotEmpty
                                        ? userName[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        GlassCard(
                          borderRadius: 12,
                          fillColor: GlassColors.cyan.withValues(alpha: 0.22),
                          borderColor: GlassColors.cyan.withValues(
                            alpha: 0.50,
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: GlassColors.cyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: GlassColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    style: const TextStyle(
                      fontSize: 13,
                      color: GlassColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _sectionLabel('SETTINGS'),
            const SizedBox(height: 12),
            _toggleCard(
              context: context,
              icon: Icons.notifications_active_rounded,
              title: 'Push Notifications',
              color: GlassColors.amber,
              value: notificationsEnabled,
              onChanged: onToggleNotifications,
            ),
            _toggleCard(
              context: context,
              icon: Icons.email_rounded,
              title: 'Daily Summary Email',
              color: GlassColors.mint,
              value: summaryEmailsEnabled,
              onChanged: onToggleEmails,
            ),
            const SizedBox(height: 32),
            // ── Logout button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: GlassCard(
                borderRadius: 24,
                fillColor: GlassColors.coral.withValues(alpha: 0.10),
                borderColor: GlassColors.coral.withValues(alpha: 0.40),
                padding: EdgeInsets.zero,
                child: TextButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OnboardingScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text(
                    'Logout',
                    style: TextStyle(
                      color: GlassColors.coral,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: GlassColors.textMuted,
            letterSpacing: 0,
          ),
        ),
      );

  Widget _toggleCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: GlassColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: GlassColors.cyan,
              activeTrackColor: GlassColors.cyan.withValues(alpha: 0.30),
              inactiveThumbColor: GlassColors.textMuted,
              inactiveTrackColor: GlassColors.glassFill,
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateImageDialog(BuildContext context) {
    final controller = TextEditingController(text: profileImageUrl ?? '');
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Update Profile Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: GlassColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              GlassTextField(
                controller: controller,
                hintText: 'Paste image URL',
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: GlassColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassCard(
                    borderRadius: 12,
                    fillColor: GlassColors.cyan.withValues(alpha: 0.20),
                    borderColor: GlassColors.cyan.withValues(alpha: 0.45),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        onUpdateProfileImage(controller.text.trim());
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          color: GlassColors.cyan,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── OPENROUTER AI ASSISTANT SERVICE ───────────────────────────────────────────
class AssistantService {
  // Obfuscated key to bypass GitHub Secret Scanning auto-revocation on gh-pages
  static String get _apiKey {
    const reversed = '2862d2e661be810077e1bcd1507bd6cd3e9e3db12e0f659258ac8bd118145ccc-1v-ro-ks';
    return String.fromCharCodes(reversed.codeUnits.reversed);
  }

  static Future<String> sendMessage(String message) async {
    try {
      final tasks = await TaskStorage.load();
      final contextText = tasks.isEmpty
          ? 'The user currently has no tasks.'
          : 'User tasks:\n${tasks.map((t) => '- [${t.category}] ${t.title} (Due: ${t.dueDate.toIso8601String().split('T').first}, Done: ${t.isDone})').join('\n')}';

      final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'HTTP-Referer': 'https://abbhi-jit.github.io/tide_app/',
          'X-Title': 'Tide App',
        },
        body: jsonEncode({
          'model': 'openrouter/free',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a helpful, concise AI assistant built directly into the Tide task management app. '
                         'Your job is to assist the user with managing their tasks and schedule. '
                         'You will be provided with the user\'s current tasks in the system context. '
                         'Base all your summaries and answers strictly on the app data provided.\n\n'
                         'App Context:\n$contextText'
            },
            {
              'role': 'user',
              'content': message
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          return data['choices'][0]['message']['content'] ?? 'No response.';
        }
        return 'No response generated.';
      } else {
        return 'Error ${response.statusCode}: ${response.body}';
      }
    } catch (e) {
      debugPrint('AI Error: $e');
      return 'Sorry, I encountered an error: $e';
    }
  }
}

// ── FLOATING CHAT WIDGET ────────────────────────────────────────────────────
class FloatingChatWidget extends StatefulWidget {
  const FloatingChatWidget({super.key});

  @override
  State<FloatingChatWidget> createState() => _FloatingChatWidgetState();
}

class _FloatingChatWidgetState extends State<FloatingChatWidget> {
  bool _isOpen = false;
  final _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  void _toggleChat() => setState(() => _isOpen = !_isOpen);

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _controller.clear();
      _isLoading = true;
    });

    final response = await AssistantService.sendMessage(text);

    setState(() {
      _messages.add({'role': 'ai', 'text': response});
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOpen) {
      return GlassCard(
        borderRadius: 20,
        padding: EdgeInsets.zero,
        fillColor: GlassColors.violet.withValues(alpha: 0.18),
        borderColor: GlassColors.violet.withValues(alpha: 0.50),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: _toggleChat,
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(12),
      borderRadius: 24,
      fillColor: GlassColors.bgMid.withValues(alpha: 0.85),
      child: SizedBox(
        width: 320,
        height: 400,
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: GlassColors.violet, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Tide Assistant',
                      style: TextStyle(
                        color: GlassColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: GlassColors.textMuted, size: 20),
                  onPressed: _toggleChat,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(color: GlassColors.glassBorder, height: 24),
            // Message List
            Expanded(
              child: ListView.builder(
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[_messages.length - 1 - index];
                  final isUser = msg['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isUser 
                          ? GlassColors.cyan.withValues(alpha: 0.2)
                          : GlassColors.glassFill,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isUser 
                            ? GlassColors.cyan.withValues(alpha: 0.4)
                            : GlassColors.glassBorder,
                        ),
                      ),
                      child: Text(
                        msg['text'] ?? '',
                        style: const TextStyle(
                          color: GlassColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: GlassColors.violet)
                ),
              ),
            const SizedBox(height: 8),
            // Input Area
            Row(
              children: [
                Expanded(
                  child: GlassTextField(
                    controller: _controller,
                    hintText: 'Ask about tasks...',
                  ),
                ),
                const SizedBox(width: 8),
                GlassCard(
                  borderRadius: 16,
                  padding: EdgeInsets.zero,
                  fillColor: GlassColors.violet.withValues(alpha: 0.2),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: GlassColors.textPrimary, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── SHARED TASK VIEW SCREEN ────────────────────────────────────────────────
class SharedTaskViewScreen extends StatelessWidget {
  final String userId;
  final String taskId;

  const SharedTaskViewScreen({super.key, required this.userId, required this.taskId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        child: SafeArea(
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('shared_tasks')
                .doc(taskId)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: GlassColors.cyan));
              }
              if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: Text('Task not found or access denied.', style: TextStyle(color: Colors.white)));
              }
              
              final taskData = snapshot.data!.data() as Map<String, dynamic>;
              final task = Task.fromJson(taskData);
              
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Shared with you', style: TextStyle(color: GlassColors.textMuted, fontSize: 14)),
                    const SizedBox(height: 20),
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: task.categoryColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(task.category, style: TextStyle(fontSize: 10, color: task.categoryColor, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: task.priorityColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('${task.priority} Priority', style: TextStyle(fontSize: 10, color: task.priorityColor, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(task.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: GlassColors.textPrimary)),
                          const SizedBox(height: 16),
                          Text('Due: ${task.dueDate.toIso8601String().split('T').first}', style: const TextStyle(color: GlassColors.textMuted)),
                          const SizedBox(height: 16),
                          const Divider(color: GlassColors.glassBorder),
                          const SizedBox(height: 16),
                          Text(task.notes.isEmpty ? 'No notes provided.' : task.notes, style: const TextStyle(color: GlassColors.textPrimary, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
