import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
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
  int _mode = 0; // 0 = upload, 1 = record

  // Upload
  String? _filePath;
  String? _fileName;

  // Record
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;

  // Common
  bool _processing = false;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _pickFile() async {
    if (Platform.isAndroid) {
      // Android 13+: READ_MEDIA_AUDIO; older: READ_EXTERNAL_STORAGE
      final audioStatus = await Permission.audio.request();
      if (!audioStatus.isGranted) {
        final storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted) {
          setState(() => _error =
              'Permiso denegado. Ve a Ajustes > Aplicaciones > ClassMind > Permisos y activa Archivos multimedia.');
          return;
        }
      }
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _filePath = result.files.first.path;
      _fileName = result.files.first.name;
      _error = null;
    });
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      setState(() => _error =
          'Permiso de micrófono denegado. Ve a Ajustes > Aplicaciones > ClassMind > Permisos y activa Micrófono.');
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/cm_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _filePath = null;
        _fileName = null;
        _recordDuration = Duration.zero;
        _error = null;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordDuration += const Duration(seconds: 1));
      });
    } catch (e) {
      setState(() => _error = 'Error al iniciar grabación: $e');
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _timer = null;
    try {
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _filePath = path;
        _fileName = 'Grabación (${_formatDuration(_recordDuration)})';
      });
    } catch (e) {
      setState(() {
        _isRecording = false;
        _error = 'Error al detener grabación: $e';
      });
    }
  }

  Future<void> _process() async {
    if (_filePath == null) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final note =
          await ApiService.processAudio(_filePath!, widget.subject.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.notesGenerated),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
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
    final hasFile = _filePath != null && !_isRecording;

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
                                  color: colorScheme.primary
                                      .withOpacity(0.7)),
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
            if (widget.subject.hasPdf)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 14, color: Colors.green.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(S.pdfLoadedDesc,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Mode toggle
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _modeButton(0, Icons.upload_file, 'Subir archivo',
                      colorScheme),
                  _modeButton(1, Icons.mic, 'Grabar', colorScheme),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Content
            if (_mode == 0)
              _buildUploadArea(colorScheme, hasFile)
            else
              _buildRecordArea(colorScheme),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade600, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: TextStyle(
                              color: Colors.red.shade700, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],

            const Spacer(),

            // Process button
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (!hasFile || _processing) ? null : _process,
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

  Widget _modeButton(
      int index, IconData icon, String label, ColorScheme cs) {
    final selected = _mode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!_isRecording) setState(() { _mode = index; _error = null; });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadArea(ColorScheme cs, bool hasFile) {
    return GestureDetector(
      onTap: _processing ? null : _pickFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 160,
        decoration: BoxDecoration(
          color: hasFile
              ? cs.primary.withOpacity(0.07)
              : Colors.grey.shade50,
          border: Border.all(
            color: hasFile ? cs.primary : Colors.grey.shade300,
            width: hasFile ? 2 : 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFile ? Icons.audio_file : Icons.upload_file_outlined,
              size: 48,
              color: hasFile ? cs.primary : Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              hasFile ? (_fileName ?? S.selectFile) : S.selectFile,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: hasFile ? cs.primary : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            if (!hasFile) ...[
              const SizedBox(height: 4),
              Text('MP3, WAV, M4A, OGG, AAC…',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecordArea(ColorScheme cs) {
    final hasRecording = _filePath != null && !_isRecording;
    return Center(
      child: Column(
        children: [
          if (_isRecording)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _formatDuration(_recordDuration),
                style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade600),
              ),
            ),
          if (hasRecording)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.green.shade600, size: 44),
                  const SizedBox(height: 8),
                  Text(
                    _fileName ?? 'Grabación lista',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700),
                  ),
                ],
              ),
            ),
          GestureDetector(
            onTap: _processing
                ? null
                : (_isRecording ? _stopRecording : _startRecording),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red.shade600 : cs.primary,
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? Colors.red : cs.primary)
                        .withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop_rounded : Icons.mic,
                color: Colors.white,
                size: 42,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isRecording
                ? 'Grabando… toca para detener'
                : hasRecording
                    ? 'Toca para volver a grabar'
                    : 'Toca el micrófono para grabar',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
