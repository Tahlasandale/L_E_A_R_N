/// Représente un item brut de carte pour l'import / export CSV
class CsvCardItem {
  final String front;
  final String back;

  const CsvCardItem({
    required this.front,
    required this.back,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CsvCardItem &&
          runtimeType == other.runtimeType &&
          front == other.front &&
          back == other.back;

  @override
  int get hashCode => front.hashCode ^ back.hashCode;
}

/// Service d'analyse et d'exportation CSV avec séparateurs personnalisables
class CsvService {
  /// Parse une chaîne de caractères CSV en une liste de [CsvCardItem]
  /// Assure strictement le format d'une seule ligne par question/réponse.
  static List<CsvCardItem> parseCsv(
    String rawContent, {
    String delimiter = ',',
    String? lineSeparator,
  }) {
    final List<CsvCardItem> result = [];
    if (rawContent.trim().isEmpty) return result;

    List<String> rawLines;
    if (lineSeparator != null && lineSeparator.isNotEmpty) {
      rawLines = rawContent.split(lineSeparator);
    } else {
      // Séparation par ligne standard (\r\n ou \n)
      rawLines = rawContent.split(RegExp(r'\r?\n'));
    }

    for (var rawLine in rawLines) {
      var line = rawLine.trim();
      if (line.isEmpty) continue;

      // Nettoyer les sauts de ligne internes s'il y en avait
      line = line.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

      // Trouver le premier délimiteur
      final delimIndex = _findFirstUnquotedDelimiter(line, delimiter);
      if (delimIndex == -1) continue;

      String front = line.substring(0, delimIndex).trim();
      String back = line.substring(delimIndex + delimiter.length).trim();

      // Enlever d'éventuels guillemets englobants
      front = _unquote(front);
      back = _unquote(back);

      // Règle d'or : garantir une seule ligne brute
      front = front.replaceAll(RegExp(r'\s+'), ' ').trim();
      back = back.replaceAll(RegExp(r'\s+'), ' ').trim();

      if (front.isNotEmpty && back.isNotEmpty) {
        result.add(CsvCardItem(front: front, back: back));
      }
    }

    return result;
  }

  /// Exporte une liste de [CsvCardItem] en chaîne CSV avec le délimiteur choisi
  static String exportCsv(
    List<CsvCardItem> cards, {
    String delimiter = ',',
    String lineEnding = '\n',
  }) {
    final buffer = StringBuffer();

    for (int i = 0; i < cards.length; i++) {
      final card = cards[i];
      // Sanitiser pour garantir une ligne
      final front = card.front.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
      final back = card.back.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

      final escapedFront = _escapeIfNeeded(front, delimiter);
      final escapedBack = _escapeIfNeeded(back, delimiter);

      buffer.write('$escapedFront$delimiter$escapedBack');
      if (i < cards.length - 1) {
        buffer.write(lineEnding);
      }
    }

    return buffer.toString();
  }

  static int _findFirstUnquotedDelimiter(String line, String delimiter) {
    bool inQuotes = false;
    for (int i = 0; i <= line.length - delimiter.length; i++) {
      if (line[i] == '"') {
        inQuotes = !inQuotes;
      } else if (!inQuotes && line.substring(i, i + delimiter.length) == delimiter) {
        return i;
      }
    }
    // Si pas trouvé sans guillemets, fallback sur premier index
    return line.indexOf(delimiter);
  }

  static String _unquote(String str) {
    if (str.length >= 2 && str.startsWith('"') && str.endsWith('"')) {
      return str.substring(1, str.length - 1).replaceAll('""', '"');
    }
    return str;
  }

  static String _escapeIfNeeded(String text, String delimiter) {
    if (text.contains(delimiter) || text.contains('"')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }
}
