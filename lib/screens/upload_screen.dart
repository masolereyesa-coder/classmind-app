import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../models/subject.dart';
import '../l10n/strings.dart';

class UploadScreen extends StatefulWidget {
  final Subject? preselectedSubject;
  const UploadScreen({super.key, this.preselectedSubject});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  List<Subject> _subjects = [];
  Subject? _selectedSubject;
  String? _filePath;
  String? _fileName;
  bool _loading = false;
  bool _processing = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _selectedSubject = widget.preselectedSubject;
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() => _loading = true);
    try {
      final subs = await ApiService.getSubjects();
      setState(() {
        _subjects = subs;
        if (_selectedSubject == null && subs.isNotEmpty) _selectedSubject = subs.first;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['m4a', 'mp3', 'wav', 'aac', 'ogg', 'mp4'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() { _filePath = result.files.single.path; _fileName = result.files.single.name; });
    }
  }

  Future<void> _process() async {
    if (_filePath == null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.noFileSelected))); return; }
    if (_selectedSubject == null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.error))); return; }
    setState(() { _processing = true; _status = S.processing; });
    try {
      final note = await ApiService.processAudio(_filePath!, _selectedSubject!.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.processing), backgroundColor: Colors.green));
      Navigator.pop(context);
      Navigator.pushNamed(context, '/note', arguments: note);
    } catch (e) {
      setState(() { _processing = false; _status = ''; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.error}: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.uploadAudio)),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : _processing
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(width: 80, height: 80, child: CircularProgressIndicator(strokeWidth: 6)),
                  const SizedBox(height: 32),
                  Text(_status, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                ]))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('1. ${S.selectFile}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _pickFile,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            border: Border.all(color: _filePath != null ? const Color(0xFF6C63FF) : Colors.grey.shade700, width: 2),
                            borderRadius: BorderRadius.circular(16),
                            color: _filePath != null ? const Color(0xFF6C63FF).withOpacity(0.1) : const Color(0xFF1E1E1E),
                          ),
                          child: Column(children: [
                            Icon(_filePath != null ? Icons.audio_file : Icons.upload_file, size: 48, color: _filePath != null ? const Color(0xFF6C63FF) : Colors.grey),
                            const SizedBox(height: 8),
                            Text(_fileName ?? S.noFileSelected,
                              style: TextStyle(color: _filePath != null ? const Color(0xFF6C63FF) : Colors.grey,
                                fontWeight: _filePath != null ? FontWeight.bold : FontWeight.normal),
                              textAlign: TextAlign.center),
                            if (_filePath == null) ...[const SizedBox(height: 4), const Text('MP3, M4A, WAV, AAC', style: TextStyle(color: Colors.grey, fontSize: 12))],
                          ]),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text('2. ${S.subjectName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Subject>(
                        value: _selectedSubject,
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.menu_book)),
                        hint: Text(S.subjectName),
                        dropdownColor: const Color(0xFF1E1E1E),
                        items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                        onChanged: (s) => setState(() => _selectedSubject = s),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.blue.shade900.withOpacity(0.3), borderRadius: BorderRadius.circular(12)),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade300, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text('Whisper AI transcribira el audio. La IA generara notas estructuradas con conceptos clave, resumen y preguntas de examen.', style: TextStyle(color: Colors.blue.shade300, fontSize: 13))),
                        ]),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(height: 56,
                        child: ElevatedButton.icon(
                          onPressed: (_filePath != null && _selectedSubject != null) ? _process : null,
                          icon: const Icon(Icons.auto_awesome),
                          label: Text(S.process, style: const TextStyle(fontSize: 16)),
                        )),
                    ],
                  ),
                ),
    );
  }
}
