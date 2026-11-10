import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../l10n/strings.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _urlController.text = ApiService.serverUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    await ApiService.setServerUrl(url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.urlSaved), backgroundColor: const Color(0xFF6C63FF)),
      );
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }

  Future<void> _toggleLanguage(bool val) async {
    S.isEnglish = val;
    langNotifier.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isEnglish', val);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.settings)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language toggle
            Card(
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.language, color: Color(0xFF6C63FF)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(S.languageLabel, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text('ES', style: TextStyle(color: !S.isEnglish ? const Color(0xFF6C63FF) : Colors.grey, fontWeight: FontWeight.bold)),
                    Switch(
                      value: S.isEnglish,
                      activeColor: const Color(0xFF6C63FF),
                      onChanged: _toggleLanguage,
                    ),
                    Text('EN', style: TextStyle(color: S.isEnglish ? const Color(0xFF6C63FF) : Colors.grey, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(S.serverUrl, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'https://classmind-backend-umtc.onrender.com/api/v1',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _saveUrl,
              icon: const Icon(Icons.save),
              label: Text(S.saveUrl),
            ),
            const Divider(height: 32),
            Text(S.account, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: Text(S.signOut),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
