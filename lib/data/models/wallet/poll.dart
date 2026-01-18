import 'package:wai_life_assistant/data/enum/pollquestiontype.dart';

class Poll {
  final String id;
  final String title;
  final String functionName;
  final DateTime expiresOn;
  final List<String> recipients;
  final List<PollQuestion> questions;

  Poll({
    required this.id,
    required this.title,
    required this.functionName,
    required this.expiresOn,
    required this.recipients,
    required this.questions,
  });
}

class PollQuestion {
  final String id;
  final String question;
  final PollQuestionType type;
  final List<String>? options; // for choice questions

  PollQuestion({
    required this.id,
    required this.question,
    required this.type,
    this.options,
  });
}
