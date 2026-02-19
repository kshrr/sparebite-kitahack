import 'package:flutter/material.dart';

class AuthPage extends StatelessWidget {
  final String role;

  const AuthPage({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("$role Login / Register")),
      body: Center(
        child: Text(
          "Login / Register as $role",
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}
