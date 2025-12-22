import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'crypto_service.dart';

class ApiService {
  static final ApiService instance = ApiService._init();
  late final Dio _dio;
  String? _token;

  ApiService._init() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    // Add interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
            print('🔐 Sending request to ${options.path} with token');
          } else {
            print('⚠️ Sending request to ${options.path} WITHOUT token');
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          print('API Error on ${error.requestOptions.path}: ${error.response?.statusCode} - ${error.message}');
          if (error.response != null) {
            print('Response data: ${error.response?.data}');
          }
          return handler.next(error);
        },
      ),
    );
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
    String email,
    String password,
    String publicKey,
  ) async {
    try {
      print('API Service - Registering user: $username');
      print('API Service - PublicKey: ${publicKey.substring(0, 20)}...');

      final response = await _dio.post(
        '/auth/register',
        data: {
          'username': username,
          'email': email,
          'password': password,
          'publicKey': publicKey,
        },
      );
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
      final response = await _dio.post(
        '/auth/login',
        data: {'username': username, 'password': password},
      );
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
      final response = await _dio.get(
        '/users/search',
        queryParameters: {'query': query},
      );
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
      final response = await _dio.get(
        '/messages/$userId',
        queryParameters: {'limit': limit, 'skip': skip},
      );
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

  // Profile endpoints
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _dio.get('/profile/me');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadAvatar(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(filePath),
      });

      final response = await _dio.post(
        '/profile/upload-avatar',
        data: formData,
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateProfile(String email) async {
    try {
      final response = await _dio.put(
        '/profile/update',
        data: {'email': email},
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteAvatar() async {
    try {
      final response = await _dio.delete('/profile/delete-avatar');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Admin endpoints
  Future<Map<String, dynamic>> getUsers({
    int page = 1,
    int limit = 20,
    String search = '',
    String role = '',
    String status = '',
  }) async {
    try {
      final response = await _dio.get(
        '/admin/users',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (search.isNotEmpty) 'search': search,
          if (role.isNotEmpty) 'role': role,
          if (status.isNotEmpty) 'status': status,
        },
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> banUser(String userId, String reason) async {
    try {
      final response = await _dio.post(
        '/admin/ban-user',
        data: {'userId': userId, 'reason': reason},
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateUserRole(
    String userId,
    String role,
  ) async {
    try {
      final response = await _dio.post(
        '/admin/update-role',
        data: {'userId': userId, 'role': role},
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final response = await _dio.get('/admin/stats');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  String getAvatarUrl(String? avatar) {
    if (avatar == null || avatar.isEmpty) return '';
    return '${AppConfig.baseUrl}$avatar';
  }

  // Group chat endpoints
  Future<Map<String, dynamic>> createGroup({
    required String name,
    String? avatar,
    String? description,
    String? password,
    bool isPrivate = true,
    required List<Map<String, String>> encryptedSessionKeys,
  }) async {
    try {
      final response = await _dio.post(
        '/groups/create',
        data: {
          'name': name,
          if (avatar != null) 'avatar': avatar,
          if (description != null && description.isNotEmpty) 'description': description,
          if (password != null && password.isNotEmpty) 'password': password,
          'isPrivate': isPrivate,
          'encryptedSessionKeys': encryptedSessionKeys,
        },
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> joinGroup({
    required String roomId,
    String? password,
  }) async {
    try {
      final response = await _dio.post(
        '/groups/join',
        data: {
          'roomId': roomId,
          if (password != null) 'password': password,
        },
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getMyGroups() async {
    try {
      final response = await _dio.get('/groups');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getGroupDetails(String roomId) async {
    try {
      final response = await _dio.get('/groups/$roomId');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> discoverPublicGroups() async {
    try {
      final response = await _dio.get('/groups/discover/public');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> kickMember({
    required String roomId,
    required String memberIdToKick,
    required List<Map<String, String>> newEncryptedSessionKeys,
  }) async {
    try {
      final response = await _dio.post(
        '/api/groups/$roomId/kick',
        data: {
          'memberIdToKick': memberIdToKick,
          'newEncryptedSessionKeys': newEncryptedSessionKeys,
        },
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> leaveGroup(String roomId) async {
    try {
      final response = await _dio.post('/groups/$roomId/leave');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteGroup(String roomId) async {
    try {
      final response = await _dio.delete('/groups/$roomId');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addGroupMember({
    required String roomId,
    required String userId,
    required String encryptedSessionKey,
  }) async {
    try {
      final response = await _dio.post(
        '/api/groups/$roomId/add-member',
        data: {
          'userId': userId,
          'encryptedSessionKey': encryptedSessionKey,
        },
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }


  Future<String> getPrivateKey() async {
    final privateKey = await CryptoService.instance.getRSAPrivateKey();
    if (privateKey == null) {
      throw Exception('RSA private key not found. Please generate keys first.');
    }
    return privateKey;
  }

  Future<String> getPublicKey() async {
    final publicKey = await CryptoService.instance.getRSAPublicKey();
    if (publicKey == null) {
      throw Exception('RSA public key not found. Please generate keys first.');
    }
    return publicKey;
  }

  // Get current user profile
  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final response = await _dio.get('/profile/me');
      return response.data;
    } catch (e) {
      print('Error getting profile: $e');
      rethrow;
    }
  }

  // Alias for backward compatibility
  Future<Map<String, dynamic>> getCurrentUser() async {
    return await getMyProfile();
  }

  // Upload file
  Future<Map<String, dynamic>> uploadFile(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post('/files/upload', data: formData);
      return response.data;
    } catch (e) {
      print('Error uploading file: $e');
      rethrow;
    }
  }
}
