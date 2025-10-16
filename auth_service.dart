import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Lấy user hiện tại
  User? get currentUser => _client.auth.currentUser;

  /// Lấy session hiện tại
  Session? get currentSession => _client.auth.currentSession;

  /// Stream theo dõi thay đổi trạng thái đăng nhập
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Đăng nhập bằng Email & Password
  Future<String?> signIn(Account account) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: account.email.trim(),
        password: account.password.trim(),
      );

      if (response.user == null) {
        return 'Đăng nhập thất bại';
      }

      // ✅ Cập nhật thời gian hoạt động
      await _client.from('profiles').update({
        'last_active': DateTime.now().toIso8601String(),
      }).eq('user_id', response.user!.id);

      return null; // ✅ Thành công
    } on AuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      return 'Lỗi không xác định: ${e.toString()}';
    }
  }

  /// ✅ Đăng ký tài khoản mới + cập nhật profile (bỏ avatar)
  Future<String?> signUp(Account account, Profile profile) async {
    try {
      final response = await _client.auth.signUp(
        email: account.email.trim(),
        password: account.password.trim(),
      );

      final user = response.user;
      if (user == null) return 'Đăng ký thất bại.';

      // ⏳ Chờ Supabase tạo dòng profile rỗng
      await _waitForProfile(user.id);

      // 📝 Cập nhật thông tin hồ sơ người dùng đầy đủ
      await _client.from('profiles').update({
        'user_id': user.id,
        'email': profile.email,
        'full_name': profile.fullName,
        'phone': profile.phone,
        'bio': profile.bio,
        'avatar_url': null, // ❌ Không dùng avatar
        'date_of_birth': profile.dateOfBirth?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'last_active': DateTime.now().toIso8601String(),
        'storage_quota': 1024,
        'auth_provider': 'email',
      }).eq('user_id', user.id);

      return null; // ✅ Thành công
    } on AuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      final error = e.toString().toLowerCase();
      if (error.contains('duplicate key')) {
        return 'Email này đã tồn tại trong hồ sơ người dùng';
      } else if (error.contains('invalid input syntax for type uuid')) {
        return 'Lỗi UUID — có thể đang gửi sai định dạng id';
      }
      return 'Lỗi server: ${e.toString()}';
    }
  }

  /// 🕓 Chờ Supabase tạo profile rỗng xong
  Future<void> _waitForProfile(String userId) async {
    for (int i = 0; i < 5; i++) {
      final res = await _client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (res != null) return; // ✅ Dòng đã tồn tại
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  /// Đăng nhập với Google
  Future<String?> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.example.my_new_app://login-callback/',
        queryParams: {'prompt': 'select_account'},
      );
      return null;
    } on AuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      return 'Lỗi không xác định: ${e.toString()}';
    }
  }

  /// Đăng nhập với GitHub
  Future<String?> signInWithGitHub() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.github,
        redirectTo: 'com.example.my_new_app://login-callback/',
        queryParams: {'prompt': 'select_account'},
      );
      return null;
    } on AuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      return 'Lỗi không xác định: ${e.toString()}';
    }
  }

  /// Đăng xuất
  Future<String?> signOut() async {
    try {
      await _client.auth.signOut();
      return null;
    } on AuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      return 'Lỗi không xác định: ${e.toString()}';
    }
  }

  /// Gửi email quên mật khẩu (reset password)
  Future<String?> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'com.example.my_new_app://reset-password/',
      );
      return null;
    } on AuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      return 'Lỗi không xác định: ${e.toString()}';
    }
  }

  /// Xử lý lỗi auth chi tiết
  String _handleAuthError(AuthException e) {
    switch (e.statusCode) {
      case '400':
        if (e.message.contains('Invalid login credentials')) {
          return 'Email hoặc mật khẩu không đúng';
        } else if (e.message.contains('Email not confirmed')) {
          return 'Vui lòng xác nhận email trước khi đăng nhập';
        } else if (e.message.contains('User already registered')) {
          return 'Email này đã được đăng ký';
        }
        return 'Thông tin không hợp lệ';
      case '422':
        if (e.message.contains('Password should be at least')) {
          return 'Mật khẩu phải có ít nhất 6 ký tự';
        } else if (e.message.contains('Email')) {
          return 'Email không hợp lệ';
        }
        return 'Dữ liệu không hợp lệ';
      case '429':
        return 'Quá nhiều yêu cầu. Vui lòng thử lại sau';
      case '500':
        return 'Lỗi server. Vui lòng thử lại sau';
      default:
        return e.message;
    }
  }
}
