// lib/core/models/resume_model.dart
//
// Plain-Dart models (no code-gen needed) matching the backend schemas exactly.
// Resume → ResumeVersion → AnalysisResult

class Resume {
  final String id;
  final String userId;
  final String title;
  final String? originalFilename;
  final String? filePath;
  final String? rawText;
  final Map<String, dynamic>? parsedJson;
  final bool isMaster;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Resume({
    required this.id,
    required this.userId,
    required this.title,
    this.originalFilename,
    this.filePath,
    this.rawText,
    this.parsedJson,
    required this.isMaster,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Resume.fromJson(Map<String, dynamic> j) => Resume(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        title: j['title'] as String,
        originalFilename: j['original_filename'] as String?,
        filePath: j['file_path'] as String?,
        rawText: j['raw_text'] as String?,
        parsedJson: j['parsed_json'] as Map<String, dynamic>?,
        isMaster: j['is_master'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'original_filename': originalFilename,
        'file_path': filePath,
        'raw_text': rawText,
        'parsed_json': parsedJson,
        'is_master': isMaster,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Resume copyWith({
    String? title,
    bool? isMaster,
  }) =>
      Resume(
        id: id,
        userId: userId,
        title: title ?? this.title,
        originalFilename: originalFilename,
        filePath: filePath,
        rawText: rawText,
        parsedJson: parsedJson,
        isMaster: isMaster ?? this.isMaster,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

// ── ResumeVersion ──────────────────────────────────────────────────────────────

class ResumeVersion {
  final String id;
  final String resumeId;
  final String userId;
  final String title;
  final Map<String, dynamic> contentJson;
  final String? jobTitle;
  final String? jobDescription;
  final String? companyName;
  final String generationMode; // 'manual' | 'ai'
  final Map<String, dynamic>? generationMetadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ResumeVersion({
    required this.id,
    required this.resumeId,
    required this.userId,
    required this.title,
    required this.contentJson,
    this.jobTitle,
    this.jobDescription,
    this.companyName,
    required this.generationMode,
    this.generationMetadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ResumeVersion.fromJson(Map<String, dynamic> j) => ResumeVersion(
        id: j['id'] as String,
        resumeId: j['resume_id'] as String,
        userId: j['user_id'] as String,
        title: j['title'] as String,
        contentJson: j['content_json'] as Map<String, dynamic>,
        jobTitle: j['job_title'] as String?,
        jobDescription: j['job_description'] as String?,
        companyName: j['company_name'] as String?,
        generationMode: j['generation_mode'] as String? ?? 'manual',
        generationMetadata: j['generation_metadata'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'resume_id': resumeId,
        'user_id': userId,
        'title': title,
        'content_json': contentJson,
        'job_title': jobTitle,
        'job_description': jobDescription,
        'company_name': companyName,
        'generation_mode': generationMode,
        'generation_metadata': generationMetadata,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

// ── AnalysisResult ─────────────────────────────────────────────────────────────

class AnalysisResult {
  final String id;
  final String userId;
  final String? resumeId;
  final String? resumeVersionId;
  final int? atsScore;
  final int? recruiterScore;
  final int? overallScore;
  final Map<String, dynamic>? scoreBreakdown;
  final List<dynamic>? issues;
  final List<dynamic>? suggestions;
  final List<String>? matchedKeywords;
  final List<String>? missingKeywords;
  final String? jobTitle;
  final String? modelUsed;
  final DateTime createdAt;

  const AnalysisResult({
    required this.id,
    required this.userId,
    this.resumeId,
    this.resumeVersionId,
    this.atsScore,
    this.recruiterScore,
    this.overallScore,
    this.scoreBreakdown,
    this.issues,
    this.suggestions,
    this.matchedKeywords,
    this.missingKeywords,
    this.jobTitle,
    this.modelUsed,
    required this.createdAt,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> j) => AnalysisResult(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        resumeId: j['resume_id'] as String?,
        resumeVersionId: j['resume_version_id'] as String?,
        atsScore: j['ats_score'] as int?,
        recruiterScore: j['recruiter_score'] as int?,
        overallScore: j['overall_score'] as int?,
        scoreBreakdown: j['score_breakdown'] as Map<String, dynamic>?,
        issues: j['issues'] as List<dynamic>?,
        suggestions: j['suggestions'] as List<dynamic>?,
        matchedKeywords: (j['matched_keywords'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(),
        missingKeywords: (j['missing_keywords'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(),
        jobTitle: j['job_title'] as String?,
        modelUsed: j['model_used'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  /// Colour-coded score label
  String get scoreLabel {
    final s = overallScore ?? 0;
    if (s >= 80) return 'Excellent';
    if (s >= 60) return 'Good';
    if (s >= 40) return 'Fair';
    return 'Needs Work';
  }
}
