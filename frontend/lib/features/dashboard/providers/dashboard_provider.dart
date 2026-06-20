import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class DashboardData {
  final Map<String, dynamic> user;
  final Map<String, dynamic> summary;
  final List<dynamic> recentResumes;
  final List<dynamic> recentApplications;
  final List<dynamic> upcomingInterviews;
  final Map<String, dynamic> insight;

  DashboardData({
    required this.user,
    required this.summary,
    required this.recentResumes,
    required this.recentApplications,
    required this.upcomingInterviews,
    required this.insight,
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) => DashboardData(
        user: j['user'] as Map<String, dynamic>,
        summary: j['summary'] as Map<String, dynamic>,
        recentResumes: j['recent_resumes'] as List<dynamic>,
        recentApplications: j['recent_applications'] as List<dynamic>,
        upcomingInterviews: j['upcoming_interviews'] as List<dynamic>,
        insight: j['insight'] as Map<String, dynamic>,
      );
}

final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  final dio = ref.watch(apiClientProvider).dio;
  final res = await dio.get('/dashboard');
  return DashboardData.fromJson(res.data as Map<String, dynamic>);
});
