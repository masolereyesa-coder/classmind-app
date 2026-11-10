import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../l10n/strings.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = S.fillAllFields);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.register(_nameCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.accountCreated)));
      Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.createAccount)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade700),
                ),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade300)),
              ),
              const SizedBox(height: 16),
            ],
            TextField(controller: _nameCtrl, textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: S.fullName, prefixIcon: const Icon(Icons.person_outlined))),
            const SizedBox(height: 16),
            TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: S.email, prefixIcon: const Icon(Icons.email_outlined))),
            const SizedBox(height: 16),
            TextField(controller: _passCtrl, obscureText: _obscure,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: S.passwordHint,
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              )),
            const SizedBox(height: 32),
            SizedBox(height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(S.createAccount, style: const TextStyle(fontSize: 16)),
              )),
          ],
        ),
      ),
    );
  }
}
