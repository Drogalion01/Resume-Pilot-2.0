// lib/core/models/generation_model.dart
//
// GenerationResult and CoverLetter — matches backend generation schemas.

// ── Scoring sub-model ──────────────────────────────────────────────────────────

class ResumeScoring {
  final int atsScore;
  final int recruiterScore;
  final int overallScore;
  final List<String> matchedKeywords;
  final List<String> missingKeywords;
  final String scoreReasoning;

  const ResumeScoring({
    required this.atsScore,
    required this.recruiterScore,
    required this.overallScore,
    required this.matchedKeywords,
    required this.missingKeywords,
    required this.scoreReasoning,
  });

  factory ResumeScoring.fromJson(Map<String, dynamic> j) => ResumeScoring(
        atsScore: j['ats_score'] as int? ?? 0,
        recruiterScore: j['recruiter_score'] as int? ?? 0,
        overallScore: j['overall_score'] as int? ?? 0,
        matchedKeywords: (j['matched_keywords'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        missingKeywords: (j['missing_keywords'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        scoreReasoning: j['score_reasoning'] as String? ?? '',
      );
}

// ── GenerationResult ───────────────────────────────────────────────────────────

class GenerationResult {
  final String resumeVersionId;
  final Map<String, dynamic> tailoredResume;
  final int atsScore;
  final int recruiterScore;
  final int overallScore;
  final int? scoreImprovement;
  final List<String> matchedKeywords;
  final List<String> missingKeywords;
  final String? coverLetter;
  final String? coverLetterId;
  final Map<String, dynamic>? generationMetadata;

  const GenerationResult({
    required this.resumeVersionId,
    required this.tailoredResume,
    required this.atsScore,
    required this.recruiterScore,
    required this.overallScore,
    this.scoreImprovement,
    required this.matchedKeywords,
    required this.missingKeywords,
    this.coverLetter,
    this.coverLetterId,
    this.generationMetadata,
  });

  factory GenerationResult.fromJson(Map<String, dynamic> j) => GenerationResult(
        resumeVersionId: j['resume_version_id'] as String,
        tailoredResume: j['tailored_resume'] as Map<String, dynamic>,
        atsScore: j['ats_score'] as int? ?? 0,
        recruiterScore: j['recruiter_score'] as int? ?? 0,
        overallScore: j['overall_score'] as int? ?? 0,
        scoreImprovement: j['score_improvement'] as int?,
        matchedKeywords: (j['matched_keywords'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        missingKeywords: (j['missing_keywords'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        coverLetter: j['cover_letter'] as String?,
        coverLetterId: j['cover_letter_id'] as String?,
        generationMetadata:
            j['generation_metadata'] as Map<String, dynamic>?,
      );

  /// Quick access to scoring from the tailored_resume JSON
  ResumeScoring? get scoring {
    final s = tailoredResume['scoring'];
    if (s == null) return null;
    return ResumeScoring.fromJson(s as Map<String, dynamic>);
  }
}

// ── CoverLetter ────────────────────────────────────────────────────────────────

class CoverLetter {
  final String id;
  final String userId;
  final String? resumeVersionId;
  final String jobTitle;
  final String? companyName;
  final String content;
  final Map<String, dynamic>? generationMetadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CoverLetter({
    required this.id,
    required this.userId,
    this.resumeVersionId,
    required this.jobTitle,
    this.companyName,
    required this.content,
    this.generationMetadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CoverLetter.fromJson(Map<String, dynamic> j) => CoverLetter(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        resumeVersionId: j['resume_version_id'] as String?,
        jobTitle: j['job_title'] as String,
        companyName: j['company_name'] as String?,
        content: j['content'] as String,
        generationMetadata:
            j['generation_metadata'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}

// ── GenerationLimitInfo ────────────────────────────────────────────────────────

class GenerationLimitInfo {
  final int used;
  final int limit; // -1 = unlimited (premium)
  final DateTime? resetsAt;

  const GenerationLimitInfo({
    required this.used,
    required this.limit,
    this.resetsAt,
  });

  factory GenerationLimitInfo.fromJson(Map<String, dynamic> j) =>
      GenerationLimitInfo(
        used: j['used'] as int? ?? 0,
        limit: j['limit'] as int? ?? 3,
        resetsAt: j['resets_at'] != null
            ? DateTime.tryParse(j['resets_at'] as String)
            : null,
      );

  bool get isUnlimited => limit < 0;
  bool get isExhausted => !isUnlimited && used >= limit;
  int get remaining => isUnlimited ? 999 : (limit - used).clamp(0, limit);
}
