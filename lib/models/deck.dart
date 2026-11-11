import 'package:isar/isar.dart';
import 'flashcard.dart';

part 'deck.g.dart';

enum FsrsMode {
  intensiveMinutes, // Mode Colles (minutes)
  longTermDays,     // Mode Long terme (jours)
}

@collection
class Deck {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String name;

  @enumerated
  late FsrsMode mode = FsrsMode.intensiveMinutes;

  late DateTime createdAt = DateTime.now();

  @Backlink(to: 'deck')
  final cards = IsarLinks<Flashcard>();
}
