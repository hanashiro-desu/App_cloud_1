import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseManager {
  static late final SupabaseClient supabase;

  static Future<void> init() async {
    await Supabase.initialize(
      url: 'https://ugfdbewlrguguecndlkp.supabase.co', // 🔹 Thay bằng URL của bạn
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVnZmRiZXdscmd1Z3VlY25kbGtwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg2Mzc0NDIsImV4cCI6MjA3NDIxMzQ0Mn0.0AS6LetS_ibzR4eDu3R51iegAYLiI61wpkCwDubx4cg',                // 🔹 Thay bằng anon key của bạn
    );
    supabase = Supabase.instance.client;
  }
}
