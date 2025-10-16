import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _dateController = TextEditingController();

  DateTime? _selectedDate;

  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.subtract(const Duration(days: 3650)),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 3 : 2),
      ),
    );
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final bio = _bioController.text.trim();

    if (fullName.isEmpty) {
      _showSnackBar('Vui lòng nhập họ và tên', isError: true);
      return;
    }
    if (email.isEmpty || !_isValidEmail(email)) {
      _showSnackBar('Vui lòng nhập email hợp lệ', isError: true);
      return;
    }
    if (password.isEmpty || password.length < 6) {
      _showSnackBar('Mật khẩu phải có ít nhất 6 ký tự', isError: true);
      return;
    }
    if (password != confirmPassword) {
      _showSnackBar('Mật khẩu xác nhận không khớp', isError: true);
      return;
    }
    if (_selectedDate == null) {
      _showSnackBar('Vui lòng chọn ngày sinh', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final account = Account(email: email, password: password);
    final profile = Profile(
      id: '',
      userId: null, // sẽ được set bên AuthService sau khi tạo user
      email: email,
      fullName: fullName,
      phone: phone,
      bio: bio,
      avatarUrl: null,
      dateOfBirth: _selectedDate,
      createdAt: DateTime.now(),
      updatedAt: null,
      lastActive: DateTime.now(),
      storageQuota: 1024,
      authProvider: 'email',
    );

    final error = await _authService.signUp(account, profile);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (error != null) {
      _showSnackBar(error, isError: true);
    } else {
      _showSnackBar('Đăng ký thành công! Vui lòng kiểm tra email.', isError: false);
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF43cea2), Color(0xFF185a9d)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icons/logo.png',
                  height: 90,
                ).animate().fadeIn(duration: 800.ms).moveY(begin: -30, end: 0),
                const SizedBox(height: 20),
                Text(
                  'Tạo tài khoản',
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _fullNameController,
                        label: 'Họ và tên',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 15),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 15),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Số điện thoại',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 15),
                      GestureDetector(
                        onTap: _pickDate,
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _dateController,
                            decoration: InputDecoration(
                              labelText: 'Ngày sinh',
                              prefixIcon: const Icon(Icons.cake_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildTextField(
                        controller: _bioController,
                        label: 'Giới thiệu ngắn',
                        icon: Icons.info_outline,
                      ),
                      const SizedBox(height: 15),
                      _buildPasswordField(
                        controller: _passwordController,
                        label: 'Mật khẩu',
                        obscure: _obscurePassword,
                        toggle: () => setState(() {
                          _obscurePassword = !_obscurePassword;
                        }),
                      ),
                      const SizedBox(height: 15),
                      _buildPasswordField(
                        controller: _confirmPasswordController,
                        label: 'Xác nhận mật khẩu',
                        obscure: _obscureConfirmPassword,
                        toggle: () => setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        }),
                      ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF185a9d),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isLoading ? null : _signUp,
                          child: _isLoading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : const Text('Đăng ký', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Đã có tài khoản? Quay lại đăng nhập',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback toggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: toggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
