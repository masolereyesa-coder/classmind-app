import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/subject.dart';
import '../models/note.dart';
import '../services/api_service.dart';
import '../l10n/strings.dart';
import 'note_screen.dart';

class UploadScreen extends StatefulWidget {
  final Subject subject;
  const UploadScreen({super.key, required this.subject});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  String? _filePath;
  String? _fileName;
  bool _processing = false;
  String? _error;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'mp4', 'wav', 'm4a', 'ogg', 'webm', 'flac'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _filePath = result.files.first.path;
      _fileName = result.files.first.name;
      _error = null;
    });
  }

  Future<void> _process() async {
    if (_filePath == null) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final note = await ApiService.processAudio(_filePath!, widget.subject.id);
      if (!mounted) return;
      // ✅ Show success message (fixed from "Procesando..." bug)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.notesGenerated),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
      // Navigate to note screen and remove upload screen from stack
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => NoteScreen(note: note)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasFile = _filePath != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(S.uploadAudio),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Subject info card
            Card(
              color: colorScheme.primary.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.school_outlined,
                        color: colorScheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.subject.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary)),
                          if (widget.subject.professorName.isNotEmpty)
                            Text(
                              '${S.prof}${widget.subject.professorName}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      colorScheme.primary.withOpacity(0.7)),
                            ),
                        ],
                      ),
                    ),
                    if (widget.subject.hasPdf)
                      Tooltip(
                        message: S.pdfLoadedDesc,
                        child: Icon(Icons.picture_as_pdf,
                            color: Colors.green.shade600, size: 20),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // PDF enrichment hint
            if (widget.subject.hasPdf)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 14, color: Colors.green.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        S.pdfLoadedDesc,
                        style: TextStyle(
                            fontSize: 12, color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // File picker area
            GestureDetector(
              onTap: _processing ? null : _pickFile,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 160,
                decoration: BoxDecoration(
                  color: hasFile
                      ? colorScheme.primary.withOpacity(0.07)
                      : Colors.grey.shade50,
                  border: Border.all(
                    color: hasFile
                        ? colorScheme.primary
                        : Colors.grey.shade300,
                    width: hasFile ? 2 : 1.5,
                    // ignore: deprecated_member_use
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      hasFile
                          ? Icons.audio_file
                          : Icons.upload_file_outlined,
                      size: 48,
                      color: hasFile
                          ? colorScheme.primary
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasFile
                          ? (_fileName ?? S.selectFile)
                          : S.selectFile,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: hasFile
                            ? colorScheme.primary
                            : Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (!hasFile) ...[
                      const SizedBox(height: 4),
                      Text(
                        'MP3, MP4, WAV, M4A, OGG…',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade400),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Error message
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade600, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                            color: Colors.red.shade700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            const Spacer(),

            // Process button
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed:
                    (!hasFile || _processing) ? null : _process,
                icon: _processing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _processing ? S.processing : S.process,
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  disabledBackgroundColor: Colors.grey.shade200,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_processing)
              Text(
                S.processing,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }
}
