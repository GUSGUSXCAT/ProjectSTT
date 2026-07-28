///ปจบ.ใช้หน้านี้
library;
import 'package:flutter/material.dart';
import 'package:LumoRead/screen/Quiz.dart';
import 'package:LumoRead/screen/ReadingArticleList.dart';
import 'package:LumoRead/screen/SetListScreen.dart';
import 'package:LumoRead/screen/SpeechExerciseScreen.dart';
import 'package:LumoRead/screen/DragDropExerciseScreen.dart';
import 'package:LumoRead/screen/ClassifyExerciseScreen.dart';

class TopicRouter {
  static void navigate(
    BuildContext context,
    Map<String, dynamic> topic,
    String grade,
  ) {
    final topicId = topic['id'] as String;
    final topicName = topic['name_th'] as String;
    final mode = topic['mode'] as String? ?? 'speech';

    debugPrint('🎯 TopicRouter: Navigating to $topicName (mode: $mode)');

    if (mode == 'main_screen') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReadingArticleListScreen(
            grade: grade,
            topicId: topicId,
            topicName: topicName,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SetListScreen(
          topicId: topicId,
          topicName: topicName,
          grade: grade,
          mode: '', 
        ),
      ),
    );
  }

  static Widget getExerciseScreen({
    required String mode,
    required String grade,
    required String topicId,
    required String topicName,
    required String set,
    String? type,
  }) {
    debugPrint('🎯 TopicRouter: Getting screen for mode=$mode, set=$set, type=$type');

    switch (mode) {
      case 'speech':
        return SpeechExerciseScreen(
          grade: grade,
          topicId: topicId,
          topicName: topicName,
          set: set,
          type: type ?? '',
        );

      case 'quiz':
        return QuizScreen(
          classLevel: grade,
          topicId: topicId,
          set: set,
        );

      case 'drag_drop':
        return DragDropExerciseScreen(
          grade: grade,
          topicId: topicId,
          topicName: topicName,
          set: set,
        );

      case 'classify':
        return ClassifyExerciseScreen(
          grade: grade,
          topicId: topicId,
          topicName: topicName,
          set: set,
          type: type ?? '',
        );

      case 'main_screen':
        return ReadingArticleListScreen(
          grade: grade,
          topicId: topicId,
          topicName: topicName,
        );

      default:
        return Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('ไม่รองรับโหมด: $mode'),
                const SizedBox(height: 8),
                const Text('กรุณาติดต่อครูเพื่อแก้ไข'),
              ],
            ),
          ),
        );
    }
  }
}