import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/subject.dart';
import '../l10n/strings.dart';

class QAScreen extends StatefulWidget {
  final Subject subject;
  const QAScreen({super.key, required this.subject});
  @override
  State<QAScreen> createState() => _QAScreenState();
}

class _QAScreenState extends State<QAScreen> {
  final _questionCtrl  = TextEditingController();
  final _scrollCtrl    = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void dispose() { _questionCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    final q = _questionCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() { _messages.add({'role': 'user', 'content': q}); _isLoading = true; });
    _questionCtrl.clear();
    _scroll();
    try {
      final answer = await ApiService.askQuestion(q, widget.subject.id);
      setState(() { _messages.add({'role': 'assistant', 'content': answer}); _isLoading = false; });
      _scroll();
    } catch (e) {
      setState(() { _messages.add({'role': 'assistant', 'content': '${S.error}: $e'}); _isLoading = false; });
    }
  }

  void _scroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${S.qaTitle}${widget.subject.name}')),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.quiz, size: 64, color: Color(0xFF6C63FF)),
                    const SizedBox(height: 16),
                    Text(widget.subject.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(S.askPlaceholder, style: const TextStyle(color: Colors.grey)),
                  ]))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isLoading) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            CircleAvatar(backgroundColor: Color(0xFF6C63FF), radius: 16, child: Icon(Icons.school, color: Colors.white, size: 16)),
                            SizedBox(width: 8),
                            CircularProgressIndicator(strokeWidth: 2),
                          ]),
                        );
                      }
                      final msg   = _messages[index];
                      final isUser = msg['role'] == 'user';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isUser) ...[
                              const CircleAvatar(backgroundColor: Color(0xFF6C63FF), radius: 16, child: Icon(Icons.school, color: Colors.white, size: 16)),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isUser ? const Color(0xFF6C63FF) : const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(msg['content']!, style: TextStyle(color: isUser ? Colors.white : Colors.white70)),
                              ),
                            ),
                            if (isUser) ...[
                              const SizedBox(width: 8),
                              const CircleAvatar(backgroundColor: Colors.grey, radius: 16, child: Icon(Icons.person, color: Colors.white, size: 16)),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, -2))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _questionCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: S.askPlaceholder,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    maxLines: 3, minLines: 1,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _isLoading ? null : _send,
                  mini: true,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
