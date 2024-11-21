// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'package:flutter/material.dart';
import '../services/database_helper.dart';
//import '../main.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

// State of SignUpScreen
class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  // Handle user sign-up
  void _handleSignUp() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || name.isEmpty || password.isEmpty) {
      _showErrorDialog('Por favor, preencha todos os campos.');
      return;
    }

    // Check if user already exists
    final existingUser = await DatabaseHelper.instance.login(email, password);
    if (existingUser != null) {
      _showErrorDialog('Usuário já cadastrado com esse email.');
      return;
    }

    final newUser = {
      'email': email,
      'name': name,
      'password': password,
    };
    try {
      await DatabaseHelper.instance.insertUser(newUser);
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Sucesso'),
            content: const Text('Usuário cadastrado com sucesso!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // Return to the login screen
                },
                child: const Text('Ok'),
              )
            ],
          );
        },
      );
    } catch (e) {
      _showErrorDialog('Erro ao cadastrar usuário. Tente novamente.');
    }
  }

  // Show an error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Erro'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ok'),
            )
          ],
        );
      },
    );
  }

  // Dispose controllers to free resources
  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Building the UI of the SignUpScreen
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastre-se'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'E-mail'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome Completo'),
            ),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Senha'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _handleSignUp,
              child: const Text('Cadastrar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Return to the login screen
              },
              child: const Text('Voltar'),
            ),
          ],
        ),
      ),
    );
  }
}
