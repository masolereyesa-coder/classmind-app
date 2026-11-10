import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subject.dart';
import '../models/note.dart';

class ApiService {
  static const String _productionUrl =
      'https://classmind-backend-umtc.onrender.com/api/v1';
  static String _baseUrl = _productionUrl;
  static String? _token;

  /// Normaliza la URL: elimina trailing slash y asegura que termine en /api/v1
  static String _normalizeUrl(String url) {
    url = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (!url.endsWith('/api/v1')) {
      if (url.endsWith('/api')) {
        url = '$url/v1';
      } else if (!url.contains('/api/v1')) {
        url = '$url/api/v1';
      }
    }
    return url;
  }

  /// Detecta IPs locales / localhost
  static bool _isLocalUrl(String url) {
    return url.contains('192.168.') ||
        url.contains('10.0.') ||
        url.contains('10.1.') ||
        url.contains('172.16.') ||
        url.contains('localhost') ||
        url.contains('127.0.0.1') ||
        RegExp(r'http://\d{1,3}\.\d{1,3}\.').hasMatch(url);
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final savedUrl = prefs.getString('server_url');
    if (savedUrl != null && savedUrl.isNotEmpty && !_isLocalUrl(savedUrl)) {
      _baseUrl = _normalizeUrl(savedUrl);
    } else {
      _baseUrl = _productionUrl;
      await prefs.remove('server_url');
    }
  }

  static Future<void> setServerUrl(String url) async {
    final normalized = _normalizeUrl(url);
    _baseUrl = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', normalized);
  }

  static String get serverUrl => _baseUrl;

  static void setToken(String token) {
    _token = token;
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ── AUTH ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      _token = data['token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      await prefs.setString('user_name', data['name'] ?? '');
      return data;
    }
    throw Exception(
        jsonDecode(res.body)['detail'] ?? 'Error al iniciar sesion');
  }

  static Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body:
              jsonEncode({'name': name, 'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception(
        jsonDecode(res.body)['detail'] ?? 'Error al registrarse');
  }

  static Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_name');
  }

  static Future<String?> getSavedUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name');
  }

  // ── SUBJECTS ──────────────────────────────────────────────────────────────

  static Future<List<Subject>> getSubjects() async {
    final res = await http
        .get(Uri.parse('$_baseUrl/subjects'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final List data = body is Map ? (body['subjects'] ?? []) : body;
      return data.map((j) => Subject.fromJson(j)).toList();
    }
    throw Exception('Error al obtener materias (${res.statusCode})');
  }

  static Future<Subject> createSubject(
      String name, String professor) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/subjects'),
          headers: _headers,
          body: jsonEncode({'name': name, 'professor_name': professor}),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200 || res.statusCode == 201) {
      return Subject.fromJson(jsonDecode(res.body));
    }
    final detail = _extractDetail(res.body, 'Error al crear materia');
    throw Exception('$detail (${res.statusCode})');
  }

  static Future<void> deleteSubject(String id) async {
    await http
        .delete(Uri.parse('$_baseUrl/subjects/$id'), headers: _headers)
        .timeout(const Duration(seconds: 15));
  }

  /// Sube el PDF de presentación de una materia.
  static Future<Map<String, dynamic>> uploadSubjectPdf(
      String subjectId, String filePath) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/subjects/$subjectId/pdf'),
    );
    req.headers['Authorization'] = 'Bearer $_token';
    req.files.add(
        await http.MultipartFile.fromPath('pdf_file', filePath));

    final streamed = await req.send().timeout(const Duration(minutes: 2));
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body);
    }
    final detail = _extractDetail(res.body, 'Error al subir PDF');
    throw Exception('$detail (${res.statusCode})');
  }

  /// Elimina el PDF de una materia.
  static Future<void> deleteSubjectPdf(String subjectId) async {
    final res = await http
        .delete(
          Uri.parse('$_baseUrl/subjects/$subjectId/pdf'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Error al eliminar PDF (${res.statusCode})');
    }
  }

  // ── NOTES ─────────────────────────────────────────────────────────────────

  static Future<List<Note>> getNotes({String? subjectId}) async {
    final uri = subjectId != null
        ? Uri.parse('$_baseUrl/notes?subject_id=$subjectId')
        : Uri.parse('$_baseUrl/notes');
    final res = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final List data = body is Map ? (body['notes'] ?? body) : body;
      return data.map((j) => Note.fromJson(j)).toList();
    }
    throw Exception('Error al obtener notas (${res.statusCode})');
  }

  static Future<void> deleteNote(String id) async {
    await http
        .delete(Uri.parse('$_baseUrl/notes/$id'), headers: _headers)
        .timeout(const Duration(seconds: 15));
  }

  static Future<Note> processAudio(
      String filePath, String subjectId) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/process-audio'),
    );
    req.headers['Authorization'] = 'Bearer $_token';
    req.files.add(
        await http.MultipartFile.fromPath('audio_file', filePath));
    req.fields['subject_id'] = subjectId;

    final streamed = await req.send().timeout(const Duration(minutes: 5));
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200) {
      return Note.fromJson(jsonDecode(res.body));
    }
    final detail = _extractDetail(res.body, 'Error al procesar audio');
    throw Exception(detail);
  }

  // ── Q&A ───────────────────────────────────────────────────────────────────

  static Future<String> askQuestion(
      String question, String subjectId) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/qa'),
          headers: _headers,
          body: jsonEncode(
              {'question': question, 'subject_id': subjectId}),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode == 200) {
      return jsonDecode(res.body)['answer'] ?? '';
    }
    throw Exception('Error al obtener respuesta');
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  static String _extractDetail(String body, String fallback) {
    try {
      return jsonDecode(body)['detail'] ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}
