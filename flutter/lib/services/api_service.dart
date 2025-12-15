import 'package:dio/dio.dart';
import '../config/app_config.dart';

class ApiService {
  static final ApiService instance = ApiService._init();
  late final Dio _dio;
  String? _token;

  ApiService._init() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    // Add interceptors
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        print('API Error: ${error.message}');
        return handler.next(error);
      },
    ));
  }

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  // Auth endpoints
  Future<Map<String, dynamic>> register(
    String username,
    String password,
    String publicKey,
  ) async {
    try {
      print('API Service - Registering user: $username');
      print('API Service - PublicKey: ${publicKey.substring(0, 20)}...');
      
      final response = await _dio.post('/auth/register', data: {
        'username': username,
        'password': password,
        'publicKey': publicKey,
      });
      print('API Service - Registration successful');
      return response.data;
    } catch (e) {
      print('API Service - Registration error: $e');
      if (e is DioException) {
        print('Response data: ${e.response?.data}');
        print('Status code: ${e.response?.statusCode}');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'username': username,
        'password': password,
      });
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // User endpoints
  Future<Map<String, dynamic>> getUserPublicKey(String userId) async {
    try {
      final response = await _dio.get('/users/$userId/public-key');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> searchUsers(String query) async {
    try {
      final response = await _dio.get('/users/search', queryParameters: {
        'query': query,
      });
      return response.data['users'];
    } catch (e) {
      rethrow;
    }
  }

  // Message endpoints
  Future<List<dynamic>> getMessages(
    String userId, {
    int limit = 50,
    int skip = 0,
  }) async {
    try {
      final response = await _dio.get('/messages/$userId', queryParameters: {
        'limit': limit,
        'skip': skip,
      });
      return response.data['messages'];
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getConversations() async {
    try {
      final response = await _dio.get('/messages');
      return response.data['conversations'];
    } catch (e) {
      rethrow;
    }
  }

  // File endpoints
  Future<Map<String, dynamic>> uploadFile(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });

      final response = await _dio.post('/files/upload', data: formData);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  String getFileUrl(String filename) {
    return '${AppConfig.baseUrl}/api/files/$filename';
  }

  String getVideoStreamUrl(String filename) {
    return '${AppConfig.baseUrl}/api/files/video/$filename';
  }

  // Download file
  Future<void> downloadFile(String url, String savePath) async {
    try {
      await _dio.download(url, savePath);
    } catch (e) {
      rethrow;
    }
  }
}
