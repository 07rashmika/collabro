enum ReportTargetType {
  session,
  user;

  String toJson() => this == ReportTargetType.user ? 'USER' : 'SESSION';
}

enum ReportReason {
  spamOrAdvertising,
  harassmentOrBullying,
  hateSpeechOrDiscrimination,
  inappropriateContent,
  academicDishonesty,
  impersonationOrFakeProfile,
  scamOrPhishing,
  other;

  String toJson() {
    switch (this) {
      case ReportReason.spamOrAdvertising:
        return 'SPAM_OR_ADVERTISING';
      case ReportReason.harassmentOrBullying:
        return 'HARASSMENT_OR_BULLYING';
      case ReportReason.hateSpeechOrDiscrimination:
        return 'HATE_SPEECH_OR_DISCRIMINATION';
      case ReportReason.inappropriateContent:
        return 'INAPPROPRIATE_CONTENT';
      case ReportReason.academicDishonesty:
        return 'ACADEMIC_DISHONESTY';
      case ReportReason.impersonationOrFakeProfile:
        return 'IMPERSONATION_OR_FAKE_PROFILE';
      case ReportReason.scamOrPhishing:
        return 'SCAM_OR_PHISHING';
      case ReportReason.other:
        return 'OTHER';
    }
  }

  String get label {
    switch (this) {
      case ReportReason.spamOrAdvertising:
        return 'Spam or advertising';
      case ReportReason.harassmentOrBullying:
        return 'Harassment or bullying';
      case ReportReason.hateSpeechOrDiscrimination:
        return 'Hate speech or discrimination';
      case ReportReason.inappropriateContent:
        return 'Inappropriate content';
      case ReportReason.academicDishonesty:
        return 'Academic dishonesty (cheating)';
      case ReportReason.impersonationOrFakeProfile:
        return 'Impersonation or fake profile';
      case ReportReason.scamOrPhishing:
        return 'Scam or phishing';
      case ReportReason.other:
        return 'Other';
    }
  }
}
