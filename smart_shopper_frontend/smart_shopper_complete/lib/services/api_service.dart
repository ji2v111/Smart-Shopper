import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = "http://10.0.2.2:8000";

  static Future<void> saveSession(String token, String role,
      String email, String region) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('token',  token);
    await p.setString('role',   role);
    await p.setString('email',  email);
    await p.setString('region', region);
  }

  static Future<String?> getToken()  async => (await SharedPreferences.getInstance()).getString('token');
  static Future<String?> getRole()   async => (await SharedPreferences.getInstance()).getString('role');
  static Future<String?> getEmail()  async => (await SharedPreferences.getInstance()).getString('email');
  static Future<String?> getRegion() async =>
      (await SharedPreferences.getInstance()).getString('region') ?? 'SA';

  static Future<void> clearSession() async {
    final p = await SharedPreferences.getInstance();
    for (final k in ['token', 'role', 'email', 'region']) {
      await p.remove(k);
    }
  }

  static Future<bool> isLoggedIn() async => (await getToken()) != null;

  static Future<Map<String, String>> _headers() async {
    final t = await getToken();
    return {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      if (t != null) 'Authorization': t,
    };
  }

  // ── Auth ────────────────────────────────────────────
  static Future<Map<String, dynamic>> register(
      String email, String pass, String firstName, String lastName, String region) async {
    final r = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({
        'email': email,
        'password': pass,
        'first_name': firstName,
        'last_name': lastName,
        'region': region,
      }),
    );
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode != 200) throw (d['detail'] ?? 'Registration failed');
    return d;
  }

  static Future<Map<String, dynamic>> sendOtp(String email, String pass) async {
    final r = await http.post(
      Uri.parse('$baseUrl/send-otp'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({'email': email, 'password': pass}),
    );
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode != 200) throw (d['detail'] ?? 'Login failed');
    return d;
  }

  static Future<Map<String, dynamic>> verifyOtp(String email, String code) async {
    final r = await http.post(
      Uri.parse('$baseUrl/verify-otp'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({'email': email, 'code': code}),
    );
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode != 200) throw (d['detail'] ?? 'OTP failed');
    await saveSession(d['token'], d['role'], email, d['region'] ?? 'SA');
    return d;
  }

  // ── Image ────────────────────────────────────────────
  /// Returns a map with keys: 'b64' (base64 image), 'crop_time' (seconds), 'format'.
  static Future<Map<String, dynamic>> cropImage(File f) async {
    final t = await getToken();
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/crop'));
    req.headers['ngrok-skip-browser-warning'] = 'true';
    if (t != null) req.headers['Authorization'] = t;
    req.files.add(await http.MultipartFile.fromPath('file', f.path));
    final res = await http.Response.fromStream(await req.send());
    final d = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) throw (d['detail'] ?? 'Crop failed');
    return {
      'b64':       d['cropped_image_b64'] as String,
      'crop_time': d['crop_time'],
      'format':    d['format'] ?? 'jpeg',
    };
  }

  static Future<Map<String, dynamic>> searchByBytes(
      List<int> bytes, {String language = 'ar'}) async {
    final t = await getToken();
    final uri = Uri.parse('$baseUrl/search')
        .replace(queryParameters: {'language': language, 'pre_cropped': 'true'});
    final req = http.MultipartRequest('POST', uri);
    req.headers['ngrok-skip-browser-warning'] = 'true';
    if (t != null) req.headers['Authorization'] = t;
    req.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: 'cropped.jpg'));
    final res = await http.Response.fromStream(await req.send());
    final d = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) throw (d['detail'] ?? 'Search failed');
    return d;
  }

  // ── History & Products ───────────────────────────────
  static Future<Map<String, dynamic>> getHistory() async {
    final r = await http.get(
        Uri.parse('$baseUrl/history'), headers: await _headers());
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode != 200) throw (d['detail'] ?? 'Failed');
    return d;
  }

  static Future<Map<String, dynamic>> getProduct(int id) async {
    final r = await http.get(
        Uri.parse('$baseUrl/products/$id'), headers: await _headers());
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode != 200) throw (d['detail'] ?? 'Not found');
    return d;
  }

  // ── Admin ────────────────────────────────────────────
  static Future<Map<String, dynamic>> getUsers() async {
    final r = await http.get(
        Uri.parse('$baseUrl/users'), headers: await _headers());
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode != 200) throw (d['detail'] ?? 'Failed');
    return d;
  }

  static Future<Map<String, dynamic>> getUserDetail(int id) async {
    final r = await http.get(
        Uri.parse('$baseUrl/users/$id'), headers: await _headers());
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode != 200) throw (d['detail'] ?? 'Failed');
    return d;
  }

  static Future<void> deleteProduct(int id) async {
    final r = await http.delete(
        Uri.parse('$baseUrl/products/$id'), headers: await _headers());
    if (r.statusCode != 200) {
      throw jsonDecode(r.body)['detail'] ?? 'Failed';
    }
  }

  static Future<void> deleteAllProducts() async {
    final r = await http.delete(
        Uri.parse('$baseUrl/products'), headers: await _headers());
    if (r.statusCode != 200) {
      throw jsonDecode(r.body)['detail'] ?? 'Failed';
    }
  }

  static Future<void> deleteUser(int id) async {
    final r = await http.delete(
        Uri.parse('$baseUrl/users/$id'), headers: await _headers());
    if (r.statusCode != 200) {
      throw jsonDecode(r.body)['detail'] ?? 'Failed';
    }
  }

  static String fullImageUrl(String path) =>
      path.startsWith('http') ? path : '$baseUrl$path';

  static Future<void> updateUserRole(int id, String role) async {
    final r = await http.patch(
        Uri.parse('$baseUrl/users/$id/role'),
        headers: await _headers(),
        body: jsonEncode({'role': role}));
    if (r.statusCode != 200) {
      throw jsonDecode(r.body)['detail'] ?? 'Failed';
    }
  }

  static Future<Map<String, dynamic>> makeFirstAdmin(
      String email, String password) async {
    final r = await http.post(
      Uri.parse('$baseUrl/make-first-admin'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({'email': email, 'password': password}),
    );
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode != 200) throw (d['detail'] ?? 'Failed');
    return d;
  }
}
