import 'package:flutter_test/flutter_test.dart';
import 'package:learn_flashcards/services/csv_service.dart';

void main() {
  group('CsvService - Import', () {
    test('Importe du CSV avec séparateur virgule standard', () {
      const input = "Bonjour,Hello\nMerci,Thank you\nAu revoir,Goodbye";
      final cards = CsvService.parseCsv(input, delimiter: ',');

      expect(cards.length, 3);
      expect(cards[0].front, 'Bonjour');
      expect(cards[0].back, 'Hello');
      expect(cards[1].front, 'Merci');
      expect(cards[1].back, 'Thank you');
      expect(cards[2].front, 'Au revoir');
      expect(cards[2].back, 'Goodbye');
    });

    test('Importe avec séparateur point-virgule et retours chariot windows \\r\\n', () {
      const input = "Capitale de la France;Paris\r\nCapitale du Japon;Tokyo\r\n";
      final cards = CsvService.parseCsv(input, delimiter: ';');

      expect(cards.length, 2);
      expect(cards[0].front, 'Capitale de la France');
      expect(cards[0].back, 'Paris');
      expect(cards[1].front, 'Capitale du Japon');
      expect(cards[1].back, 'Tokyo');
    });

    test('Importe le format du prototype web (lignes séparées par des points-virgules et champs par virgule)', () {
      const input = "sin(0),0;cos(0),1;tan(0),0;";
      final cards = CsvService.parseCsv(
        input,
        delimiter: ',',
        lineSeparator: ';',
      );

      expect(cards.length, 3);
      expect(cards[0].front, 'sin(0)');
      expect(cards[0].back, '0');
      expect(cards[1].front, 'cos(0)');
      expect(cards[1].back, '1');
      expect(cards[2].front, 'tan(0)');
      expect(cards[2].back, '0');
    });

    test('Nettoie et normalise les espaces sur la ligne de chaque carte', () {
      const input = "  Question   avec   espaces  ,  Réponse   avec   espaces  \n";
      final cards = CsvService.parseCsv(input, delimiter: ',');

      expect(cards.length, 1);
      expect(cards[0].front, 'Question avec espaces');
      expect(cards[0].back, 'Réponse avec espaces');
    });

    test('Ignore les lignes vides et les lignes sans délimiteur', () {
      const input = "  \n\nValid,True\nLigneInvalideSansVirgule\nAutre,False\n  ";
      final cards = CsvService.parseCsv(input, delimiter: ',');

      expect(cards.length, 2);
      expect(cards[0].front, 'Valid');
      expect(cards[0].back, 'True');
      expect(cards[1].front, 'Autre');
      expect(cards[1].back, 'False');
    });
  });

  group('CsvService - Export', () {
    test('Exporte une liste de cartes en CSV avec délimiteur choisi', () {
      final cards = [
        CsvCardItem(front: 'sin(0)', back: '0'),
        CsvCardItem(front: 'cos(0)', back: '1'),
      ];

      final csv = CsvService.exportCsv(cards, delimiter: ';');
      expect(csv, "sin(0);0\ncos(0);1");
    });

    test('Gère les guillemets si le texte contient le délimiteur', () {
      final cards = [
        CsvCardItem(front: 'Valeurs remarquables', back: '1/2, 2/2, 3/2'),
      ];

      final csv = CsvService.exportCsv(cards, delimiter: ',');
      expect(csv, 'Valeurs remarquables,"1/2, 2/2, 3/2"');
    });
  });
}
