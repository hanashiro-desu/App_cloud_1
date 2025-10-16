import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

// 🔹 Import các màn hình
import 'views/login_page.dart';
import 'views/register_page.dart';
import 'views/forgot_password_page.dart';
import 'views/reset_password_page.dart';
import 'views/home_screen.dart'; // Giữ lại HomeScreen nếu bạn có sẵn

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Khởi tạo Supabase
  await Supabase.initialize(
    url: 'https://ugfdbewlrguguecndlkp.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVnZmRiZXdscmd1Z3VlY25kbGtwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg2Mzc0NDIsImV4cCI6MjA3NDIxMzQ0Mn0.0AS6LetS_ibzR4eDu3R51iegAYLiI61wpkCwDubx4cg',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // ✅ Bắt sự kiện reset mật khẩu từ email
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    if (event == AuthChangeEvent.passwordRecovery) {
      navigatorKey.currentState?.pushNamed('/resetPassword');
    }
  });

  runApp(const MyApp());
}

// 🔹 Ứng dụng chính
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Supabase Auth Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4facfe),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      // ✅ Route khởi động: kiểm tra login/logout
      initialRoute: '/auth',
      routes: {
        '/auth': (context) => const AuthWrapper(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/forgot': (context) => const ForgotPasswordPage(),
        '/resetPassword': (context) => const ResetPasswordPage(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

// 🔹 Xác định người dùng đang đăng nhập hay chưa
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;
        return session != null ? const HomeScreen() : const LoginPage();
      },
    );
  }
}

// 🔹 Trang chủ sau khi đăng nhập
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  User? _user;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() {
    _user = Supabase.instance.client.auth.currentUser;
    setState(() {});
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đăng xuất: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          else
            IconButton(onPressed: _confirmSignOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 80, color: Colors.white),
                const SizedBox(height: 20),
                Text(
                  '🎉 Đăng nhập thành công!',
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                if (_user != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text('Email: ${_user!.email ?? "Không có"}'),
                        const SizedBox(height: 8),
                        Text('User ID: ${_user!.id}'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
