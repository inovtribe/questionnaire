import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:questionnaire/src/app.dart';
import 'package:questionnaire/src/widgets/overall_quiz_result.dart';

Future<void> main() async {
  await Firestore.instance.settings(timestampsInSnapshotsEnabled: true);
  //runApp(App());
  runApp(MaterialApp(home: OverallQuizResult()));
}
