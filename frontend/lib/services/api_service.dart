import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic errors;

  ApiException(this.message, {this.statusCode, this.errors});

  @override
  String toString() => message;
}

class ApiService {
  static String? _token;

  static void setToken(String? token) {
    _token = token;
  }

  static String? getToken() => _token;

  static Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final body = json.decode(response.body);
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    
    throw ApiException(
      body['message'] ?? 'An error occurred',
      statusCode: response.statusCode,
      errors: body['errors'],
    );
  }

  // GET request
  static Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? queryParams}) async {
    var uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    if (queryParams != null) {
      uri = uri.replace(queryParameters: queryParams);
    }
    
    final response = await http.get(uri, headers: _headers);
    return _handleResponse(response);
  }

  // POST request
  static Future<Map<String, dynamic>> post(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    final response = await http.post(
      uri,
      headers: _headers,
      body: body != null ? json.encode(body) : null,
    );
    return _handleResponse(response);
  }

  // PUT request
  static Future<Map<String, dynamic>> put(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    final response = await http.put(
      uri,
      headers: _headers,
      body: body != null ? json.encode(body) : null,
    );
    return _handleResponse(response);
  }

  // DELETE request
  static Future<Map<String, dynamic>> delete(String endpoint) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    final response = await http.delete(uri, headers: _headers);
    return _handleResponse(response);
  }
}
