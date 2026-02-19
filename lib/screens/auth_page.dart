import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String selectedRole = "restaurant";

  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  Future<void> submit() async {
    try {
      if (isLogin) {
        // LOGIN
        await auth.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      } else {
        // REGISTER
        final userCredential = await auth.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        // Save role in Firestore
        await firestore.collection("users").doc(userCredential.user!.uid).set({
          "email": emailController.text.trim(),
          "role": selectedRole,
          "createdAt": Timestamp.now(),
        });
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Success!")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? "Login" : "Register")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),

            const SizedBox(height: 20),

            // Show role selection only when registering
            if (!isLogin)
              DropdownButton<String>(
                value: selectedRole,
                items: const [
                  DropdownMenuItem(
                    value: "restaurant",
                    child: Text("Restaurant"),
                  ),
                  DropdownMenuItem(value: "ngo", child: Text("NGO")),
                ],
                onChanged: (value) {
                  setState(() => selectedRole = value!);
                },
              ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: submit,
              child: Text(isLogin ? "Login" : "Register"),
            ),

            TextButton(
              onPressed: () {
                setState(() => isLogin = !isLogin);
              },
              child: Text(
                isLogin ? "Create account" : "Already have account? Login",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
