import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../models/subject.dart';
import '../models/note.dart';

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
    if (_filePath == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un archivo de audio'))); return; }
    if (_selectedSubject == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona una materia'))); return; }
    setState(() { _processing = true; _status = 'Subiendo audio...'; });
    try {
      setState(() => _status = 'Transcribiendo con Whisper AI...');
      final note = await ApiService.processAudio(_filePath!, _selectedSubject!.id);
      setState(() => _status = 'Listo! Notas generadas');
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notas generadas exitosamente!'), backgroundColor: Colors.green));
      Navigator.pop(context);
      Navigator.pushNamed(context, '/note', arguments: note);
    } catch (e) {
      setState(() { _processing = false; _status = ''; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subir audio de clase')),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : _processing
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(width: 80, height: 80, child: CircularProgressIndicator(strokeWidth: 6)),
                  const SizedBox(height: 32),
                  Text(_status, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  const Text('Esto puede tardar unos minutos\ndependiendo del largo del audio', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                ]))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('1. Selecciona el audio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _pickFile,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            border: Border.all(color: _filePath != null ? const Color(0xFF6C63FF) : Colors.grey.shade300, width: 2),
                            borderRadius: BorderRadius.circular(16),
                            color: _filePath != null ? const Color(0xFF6C63FF).withOpacity(0.05) : Colors.grey.shade50,
                          ),
                          child: Column(children: [
                            Icon(_filePath != null ? Icons.audio_file : Icons.upload_file, size: 48, color: _filePath != null ? const Color(0xFF6C63FF) : Colors.grey),
                            const SizedBox(height: 8),
                            Text(_fileName ?? 'Toca para seleccionar archivo',
                              style: TextStyle(color: _filePath != null ? const Color(0xFF6C63FF) : Colors.grey,
                                fontWeight: _filePath != null ? FontWeight.bold : FontWeight.normal),
                              textAlign: TextAlign.center),
                            if (_filePath == null) ...[const SizedBox(height: 4), const Text('MP3, M4A, WAV, AAC', style: TextStyle(color: Colors.grey, fontSize: 12))],
                          ]),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text('2. Selecciona la materia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Subject>(
                        value: _selectedSubject,
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.menu_book)),
                        hint: const Text('Elige una materia'),
                        items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                        onChanged: (s) => setState(() => _selectedSubject = s),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(child: Text('Whisper AI transcribira el audio en espanol. La IA generara notas estructuradas con conceptos clave, resumen y preguntas de examen.', style: TextStyle(color: Colors.blue, fontSize: 13))),
                        ]),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(height: 56,
                        child: ElevatedButton.icon(
                          onPressed: (_filePath != null && _selectedSubject != null) ? _process : null,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Procesar y generar notas', style: TextStyle(fontSize: 16)),
                        )),
                    ],
                  ),
                ),
    );
  }
}
