import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  String errorMessage = '';

  void _login() async {
    setState(() {
      loading = true;
      errorMessage = '';
    });

    final user = await _authService.login(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

    setState(() => loading = false);

    if (user != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      setState(() => errorMessage = 'Email atau password salah!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.water_drop, size: 100, color: Colors.blueAccent),
              const SizedBox(height: 10),
              const Text(
                "Smart Watering",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 40),

              // Email Field
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Password Field
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Login",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 15),

              if (errorMessage.isNotEmpty)
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
