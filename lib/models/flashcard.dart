import 'package:isar/isar.dart';
import 'deck.dart';

part 'flashcard.g.dart';

@collection
class Flashcard {
  Id id = Isar.autoIncrement;

  late String front;
  late String back;

  final deck = IsarLink<Deck>();

  int reps = 0;
  double interval = 0.0;
  double ease = 2.5;
  late DateTime dueDate = DateTime.now();
  DateTime? lastReviewed;
}
