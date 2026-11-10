import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subject.dart';
import '../models/note.dart';

class ApiService {
  static String _baseUrl = 'https://classmind-api.onrender.com/api/v1';
  static String? _token;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final savedUrl = prefs.getString('server_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
    }
  }

  static Future<void> setServerUrl(String url) async {
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);
  }

  static String get serverUrl => _baseUrl;

  static void setToken(String token) {
    _token = token;
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      _token = data['token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      await prefs.setString('user_name', data['name'] ?? '');
      return data;
    }
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Error al iniciar sesion');
  }

  static Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Error al registrarse');
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

  static Future<List<Subject>> getSubjects() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/subjects'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((j) => Subject.fromJson(j)).toList();
    }
    throw Exception('Error al obtener materias');
  }

  static Future<Subject> createSubject(String name, String professor) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/subjects'),
      headers: _headers,
      body: jsonEncode({'name': name, 'professor_name': professor}),
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return Subject.fromJson(jsonDecode(res.body));
    }
    throw Exception('Error al crear materia');
  }

  static Future<void> deleteSubject(String id) async {
    await http.delete(
      Uri.parse('$_baseUrl/subjects/$id'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));
  }

  static Future<List<Note>> getNotes({String? subjectId}) async {
    final uri = subjectId != null
        ? Uri.parse('$_baseUrl/notes?subject_id=$subjectId')
        : Uri.parse('$_baseUrl/notes');
    final res = await http.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((j) => Note.fromJson(j)).toList();
    }
    throw Exception('Error al obtener notas');
  }

  static Future<void> deleteNote(String id) async {
    await http.delete(
      Uri.parse('$_baseUrl/notes/$id'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));
  }

  static Future<Note> processAudio(String filePath, String subjectId) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/process-audio'),
    );
    req.headers['Authorization'] = 'Bearer $_token';
    req.files.add(await http.MultipartFile.fromPath('audio_file', filePath));
    req.fields['subject_id'] = subjectId;

    final streamed = await req.send().timeout(const Duration(minutes: 5));
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200) {
      return Note.fromJson(jsonDecode(res.body));
    }
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Error al procesar audio');
  }

  static Future<String> askQuestion(String question, String subjectId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/qa'),
      headers: _headers,
      body: jsonEncode({'question': question, 'subject_id': subjectId}),
    ).timeout(const Duration(seconds: 30));
    if (res.statusCode == 200) {
      return jsonDecode(res.body)['answer'] ?? '';
    }
    throw Exception('Error al obtener respuesta');
  }
}
