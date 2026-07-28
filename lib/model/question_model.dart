class QuestionModel {
  final String paragraph;
  final String question;
  final List<String> options;
  final String answer;

  QuestionModel({
    required this.paragraph,
    required this.question,
    required this.options,
    required this.answer,
  });

  factory QuestionModel.fromFirestore(Map<String, dynamic> data) {
    return QuestionModel(
      paragraph: data['paragraph'] ?? '',
      question: data['question'] ?? '',
      options: (data['options'] is List)
          ? List<String>.from(data['options']) //  กรณี options เป็น Array (ถูกต้อง)
          : (data['options'] is String) //  กรณี options เป็น String (ต้องแปลง)
              ? (data['options'] as String)
                  .replaceAll("[", "")
                  .replaceAll("]", "")
                  .replaceAll("\"", "")
                  .split(", ")
              : [],
      answer: data['answer'] ?? '',
    );
  }
}
