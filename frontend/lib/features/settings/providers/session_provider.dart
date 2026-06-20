import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class SessionData {
  final String familyId;
  final String? ipAddress;
  final String? userAgent;
  final DateTime lastActive;

  SessionData({
    required this.familyId,
    this.ipAddress,
    this.userAgent,
    required this.lastActive,
  });

  factory SessionData.fromJson(Map<String, dynamic> j) => SessionData(
        familyId: j['family_id'] as String,
        ipAddress: j['ip_address'] as String?,
        userAgent: j['user_agent'] as String?,
        lastActive: DateTime.parse(j['last_active'] as String),
      );
}

class SessionRepository {
  final Dio _dio;
  SessionRepository(this._dio);

  Future<List<SessionData>> fetchSessions() async {
    final res = await _dio.get('/users/sessions');
    return (res.data as List).map((e) => SessionData.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> revokeSession(String familyId) async {
    await _dio.delete('/users/sessions/$familyId');
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(ref.watch(apiClientProvider).dio);
});

final sessionListProvider = AsyncNotifierProvider<SessionListNotifier, List<SessionData>>(
  SessionListNotifier.new,
);

class SessionListNotifier extends AsyncNotifier<List<SessionData>> {
  @override
  Future<List<SessionData>> build() => ref.read(sessionRepositoryProvider).fetchSessions();

  Future<void> revoke(String familyId) async {
    await ref.read(sessionRepositoryProvider).revokeSession(familyId);
    state = AsyncData((state.valueOrNull ?? []).where((s) => s.familyId != familyId).toList());
  }
}
