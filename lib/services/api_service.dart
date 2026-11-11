import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subject.dart';
import '../models/note.dart';

class ApiService {
  static const String _productionUrl =
      'https://classmind-backend-umtc.onrender.com/api/v1';
  static String _baseUrl = _productionUrl;
  static String? _token;
  static String? _refreshToken; // FIX v7

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
    _refreshToken = prefs.getString('refresh_token'); // FIX v7
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

  // FIX v7: cabecera con token válido (refresca si expiró)
  static Future<Map<String, String>> get _authHeaders async {
    await _ensureValidToken();
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  // Headers síncronos para compatibilidad con código existente
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // FIX v7: verifica si el token expira pronto y lo refresca
  static Future<void> _ensureValidToken() async {
    if (_token == null) return;
    if (_isTokenExpiredOrExpiringSoon(_token!)) {
      if (_refreshToken == null) return;
      try {
        final data = await _callRefresh(_refreshToken!);
        _token = data['token'];
        _refreshToken = data['refresh_token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('refresh_token', _refreshToken!);
      } catch (_) {
        // Si falla el refresh, seguimos con el token que tenemos
      }
    }
  }

  static bool _isTokenExpiredOrExpiringSoon(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final data = json.decode(payload) as Map<String, dynamic>;
      final exp = data['exp'] as int?;
      if (exp == null) return false;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 5)));
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, String>> _callRefresh(String refreshToken) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'refresh_token': refreshToken}),
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return {
        'token': data['token'] as String,
        'refresh_token': data['refresh_token'] as String,
      };
    }
    throw Exception('Refresh fallido: ${res.statusCode}');
  }

  // ── AUTH ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 60));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      _token = data['token'];
      _refreshToken = data['refresh_token']; // FIX v7
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      await prefs.setString('refresh_token', _refreshToken ?? ''); // FIX v7
      await prefs.setString('user_name', data['name'] ?? '');
      return data;
    }
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Error al iniciar sesión');
  }

  static Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 60));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      _token = data['token'];
      _refreshToken = data['refresh_token']; // FIX v7
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      await prefs.setString('refresh_token', _refreshToken ?? ''); // FIX v7
      await prefs.setString('user_name', name);
      return data;
    }
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Error al registrarse');
  }

  static Future<void> logout() async {
    _token = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_name');
  }

  static Future<String?> getSavedUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name');
  }

  // ── SUBJECTS ──────────────────────────────────────────────────────────────

  static Future<List<Subject>> getSubjects() async {
    await _ensureValidToken();
    final res = await http
        .get(Uri.parse('$_baseUrl/subjects'), headers: _headers)
        .timeout(const Duration(seconds: 60));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final List data = body is Map ? (body['subjects'] ?? []) : body;
      return data.map((j) => Subject.fromJson(j)).toList();
    }
    throw Exception('Error al obtener materias (${res.statusCode})');
  }

  static Future<Subject> createSubject(String name, String professor) async {
    await _ensureValidToken();
    final res = await http.post(
      Uri.parse('$_baseUrl/subjects'),
      headers: _headers,
      body: jsonEncode({'name': name, 'professor_name': professor}),
    ).timeout(const Duration(seconds: 60));
    if (res.statusCode == 200 || res.statusCode == 201) {
      return Subject.fromJson(jsonDecode(res.body));
    }
    throw Exception('${_extractDetail(res.body, 'Error al crear materia')} (${res.statusCode})');
  }

  static Future<void> deleteSubject(String id) async {
    await _ensureValidToken();
    await http
        .delete(Uri.parse('$_baseUrl/subjects/$id'), headers: _headers)
        .timeout(const Duration(seconds: 60));
  }

  static Future<Map<String, dynamic>> uploadSubjectPdf(
      String subjectId, String filePath) async {
    await _ensureValidToken();
    final req = http.MultipartRequest('POST', Uri.parse('$_baseUrl/subjects/$subjectId/pdf'));
    req.headers['Authorization'] = 'Bearer $_token';
    req.files.add(await http.MultipartFile.fromPath('pdf_file', filePath));
    final streamed = await req.send().timeout(const Duration(minutes: 2));
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200 || res.statusCode == 201) return jsonDecode(res.body);
    throw Exception('${_extractDetail(res.body, 'Error al subir PDF')} (${res.statusCode})');
  }

  static Future<void> deleteSubjectPdf(String subjectId) async {
    await _ensureValidToken();
    final res = await http
        .delete(Uri.parse('$_baseUrl/subjects/$subjectId/pdf'), headers: _headers)
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Error al eliminar PDF (${res.statusCode})');
    }
  }

  // ── NOTES ─────────────────────────────────────────────────────────────────

  static Future<List<Note>> getNotes({String? subjectId}) async {
    await _ensureValidToken();
    final uri = subjectId != null
        ? Uri.parse('$_baseUrl/notes?subject_id=$subjectId')
        : Uri.parse('$_baseUrl/notes');
    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 60));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final List data = body is Map ? (body['notes'] ?? body) : body;
      return data.map((j) => Note.fromJson(j)).toList();
    }
    throw Exception('Error al obtener notas (${res.statusCode})');
  }

  static Future<void> deleteNote(String id) async {
    await _ensureValidToken();
    await http
        .delete(Uri.parse('$_baseUrl/notes/$id'), headers: _headers)
        .timeout(const Duration(seconds: 60));
  }

  // FIX v7: actualizar notas estructuradas (edición)
  static Future<void> updateNote(String noteId, String structuredNotes) async {
    await _ensureValidToken();
    final res = await http.patch(
      Uri.parse('$_baseUrl/notes/$noteId'),
      headers: _headers,
      body: jsonEncode({'structured_notes': structuredNotes}),
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Error al guardar cambios (${res.statusCode})');
    }
  }

  // FIX v7: processAudio con callback de progreso y filename para extensión
  static Future<Note> processAudio(
    String filePath,
    String subjectId, {
    void Function(String)? onStatus,
  }) async {
    await _ensureValidToken();
    onStatus?.call('Subiendo audio...');

    final filename = filePath.split(Platform.pathSeparator).last;
    final req = http.MultipartRequest('POST', Uri.parse('$_baseUrl/process-audio'));
    req.headers['Authorization'] = 'Bearer $_token';
    // FIX v7: pasar filename con extensión para que el backend detecte el formato
    req.files.add(await http.MultipartFile.fromPath(
      'audio_file',
      filePath,
      filename: filename,
    ));
    req.fields['subject_id'] = subjectId;

    final streamed = await req.send().timeout(
      const Duration(minutes: 20),
      onTimeout: () => throw Exception('Tiempo de espera agotado. El audio puede ser muy largo.'),
    );

    onStatus?.call('Transcribiendo con Whisper...');
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 200) {
      onStatus?.call('Generando notas con IA...');
      return Note.fromJson(jsonDecode(res.body));
    }
    if (res.statusCode == 401) {
      throw Exception('Sesión expirada. Vuelve a iniciar sesión.');
    }
    throw Exception(_extractDetail(res.body, 'Error al procesar audio'));
  }

  // ── Q&A ───────────────────────────────────────────────────────────────────

  // FIX v7: eliminado user_id del body
  static Future<String> askQuestion(String question, String subjectId) async {
    await _ensureValidToken();
    final res = await http.post(
      Uri.parse('$_baseUrl/qa'),
      headers: _headers,
      body: jsonEncode({'question': question, 'subject_id': subjectId}),
    ).timeout(const Duration(seconds: 30));
    if (res.statusCode == 200) return jsonDecode(res.body)['answer'] ?? '';
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
