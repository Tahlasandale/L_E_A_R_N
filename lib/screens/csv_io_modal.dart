import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../models/deck.dart';
import '../providers/deck_provider.dart';
import '../theme/catppuccin.dart';
import '../widgets/kawaii_button.dart';

class CsvIoModal {
  /// Ouvre la modale d'importation CSV
  static Future<void> showImportModal(BuildContext context, Deck deck) async {
    final textController = TextEditingController();
    final customFieldController = TextEditingController();
    final customCardController = TextEditingController();

    String selectedFieldDelimiter = ',';
    String selectedCardDelimiter = '\n';
    bool isCustomField = false;
    bool isCustomCard = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Catppuccin.mantle,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            String effectiveField = isCustomField ? customFieldController.text : selectedFieldDelimiter;
            if (effectiveField.isEmpty) effectiveField = ',';

            String? effectiveCard = isCustomCard ? customCardController.text : selectedCardDelimiter;
            if (effectiveCard.isEmpty) effectiveCard = '\n';

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Importer dans ${deck.name} 📥',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Catppuccin.sky,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Catppuccin.overlay),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 1. Séparateur Question ↔ Réponse
                    const Text(
                      '1. Séparateur Question ↔ Réponse :',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Catppuccin.text, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: isCustomField ? 'custom' : selectedFieldDelimiter,
                          dropdownColor: Catppuccin.crust,
                          style: const TextStyle(color: Catppuccin.sky, fontWeight: FontWeight.bold),
                          items: const [
                            DropdownMenuItem(value: ',', child: Text('Virgule ( , )')),
                            DropdownMenuItem(value: ';', child: Text('Point-virgule ( ; )')),
                            DropdownMenuItem(value: '\t', child: Text('Tabulation ( \\t )')),
                            DropdownMenuItem(value: '|', child: Text('Pipe ( | )')),
                            DropdownMenuItem(value: 'custom', child: Text('Personnalisé...')),
                          ],
                          onChanged: (val) {
                            if (val == 'custom') {
                              setState(() => isCustomField = true);
                            } else if (val != null) {
                              setState(() {
                                isCustomField = false;
                                selectedFieldDelimiter = val;
                              });
                            }
                          },
                        ),
                        if (isCustomField) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: customFieldController,
                              style: const TextStyle(color: Catppuccin.text),
                              decoration: const InputDecoration(
                                hintText: 'ex: ::',
                                hintStyle: TextStyle(color: Catppuccin.overlay),
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 2. Séparateur Carte ↔ Carte
                    const Text(
                      '2. Séparateur entre Flashcards :',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Catppuccin.text, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: isCustomCard ? 'custom' : selectedCardDelimiter,
                          dropdownColor: Catppuccin.crust,
                          style: const TextStyle(color: Catppuccin.sky, fontWeight: FontWeight.bold),
                          items: const [
                            DropdownMenuItem(value: '\n', child: Text('Saut de ligne ( \\n )')),
                            DropdownMenuItem(value: ';', child: Text('Point-virgule ( ; )')),
                            DropdownMenuItem(value: '\n\n', child: Text('Double saut ( \\n\\n )')),
                            DropdownMenuItem(value: '\t', child: Text('Tabulation ( \\t )')),
                            DropdownMenuItem(value: '|', child: Text('Pipe ( | )')),
                            DropdownMenuItem(value: 'custom', child: Text('Personnalisé...')),
                          ],
                          onChanged: (val) {
                            if (val == 'custom') {
                              setState(() => isCustomCard = true);
                            } else if (val != null) {
                              setState(() {
                                isCustomCard = false;
                                selectedCardDelimiter = val;
                              });
                            }
                          },
                        ),
                        if (isCustomCard) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: customCardController,
                              style: const TextStyle(color: Catppuccin.text),
                              decoration: const InputDecoration(
                                hintText: 'ex: ;;\n---',
                                hintStyle: TextStyle(color: Catppuccin.overlay),
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    KawaiiButton.secondary(
                      height: 40,
                      onPressed: () async {
                        final files = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['csv', 'txt'],
                        );
                        if (files.isNotEmpty) {
                          final content = await files.first.xFile.readAsString();
                          textController.text = content;
                        }
                      },
                      child: const Text('📂 Choisir un fichier .csv / .txt'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textController,
                      maxLines: 5,
                      style: const TextStyle(color: Catppuccin.text, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Colle tes cartes ici...\nEx: Q1${effectiveField}R1${effectiveCard == '\n' ? '\n' : effectiveCard}Q2${effectiveField}R2',
                        hintStyle: const TextStyle(color: Catppuccin.overlay),
                        filled: true,
                        fillColor: Catppuccin.crust,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Catppuccin.blue, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    KawaiiButton(
                      onPressed: () async {
                        final content = textController.text.trim();
                        if (content.isEmpty) return;

                        final provider = Provider.of<DeckProvider>(context, listen: false);
                        final count = await provider.importCsv(
                          deck: deck,
                          csvContent: content,
                          delimiter: effectiveField,
                          lineSeparator: effectiveCard == '\n' ? null : effectiveCard,
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Catppuccin.mantle,
                              content: Text(
                                '⚡ $count cartes ajoutées au paquet !',
                                style: const TextStyle(color: Catppuccin.green, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Sauvegarder les cartes ⚡'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Ouvre la modale d'exportation CSV avec réglage des deux séparateurs
  static Future<void> showExportModal(BuildContext context, Deck deck) async {
    final customFieldController = TextEditingController();
    final customCardController = TextEditingController();

    String selectedFieldDelimiter = ',';
    String selectedCardDelimiter = '\n';
    bool isCustomField = false;
    bool isCustomCard = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Catppuccin.mantle,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            String effectiveField = isCustomField ? customFieldController.text : selectedFieldDelimiter;
            if (effectiveField.isEmpty) effectiveField = ',';

            String effectiveCard = isCustomCard ? customCardController.text : selectedCardDelimiter;
            if (effectiveCard.isEmpty) effectiveCard = '\n';

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exporter ${deck.name} 📤',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Catppuccin.sky,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. Séparateur Question ↔ Réponse
                    const Text(
                      '1. Séparateur Question ↔ Réponse :',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Catppuccin.text, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: isCustomField ? 'custom' : selectedFieldDelimiter,
                          dropdownColor: Catppuccin.crust,
                          style: const TextStyle(color: Catppuccin.sky, fontWeight: FontWeight.bold),
                          items: const [
                            DropdownMenuItem(value: ',', child: Text('Virgule ( , )')),
                            DropdownMenuItem(value: ';', child: Text('Point-virgule ( ; )')),
                            DropdownMenuItem(value: '\t', child: Text('Tabulation ( \\t )')),
                            DropdownMenuItem(value: '|', child: Text('Pipe ( | )')),
                            DropdownMenuItem(value: 'custom', child: Text('Personnalisé...')),
                          ],
                          onChanged: (val) {
                            if (val == 'custom') {
                              setState(() => isCustomField = true);
                            } else if (val != null) {
                              setState(() {
                                isCustomField = false;
                                selectedFieldDelimiter = val;
                              });
                            }
                          },
                        ),
                        if (isCustomField) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: customFieldController,
                              style: const TextStyle(color: Catppuccin.text),
                              decoration: const InputDecoration(
                                hintText: 'ex: ::',
                                hintStyle: TextStyle(color: Catppuccin.overlay),
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 2. Séparateur Carte ↔ Carte
                    const Text(
                      '2. Séparateur entre Flashcards :',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Catppuccin.text, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: isCustomCard ? 'custom' : selectedCardDelimiter,
                          dropdownColor: Catppuccin.crust,
                          style: const TextStyle(color: Catppuccin.sky, fontWeight: FontWeight.bold),
                          items: const [
                            DropdownMenuItem(value: '\n', child: Text('Saut de ligne ( \\n )')),
                            DropdownMenuItem(value: ';', child: Text('Point-virgule ( ; )')),
                            DropdownMenuItem(value: '\n\n', child: Text('Double saut ( \\n\\n )')),
                            DropdownMenuItem(value: '\t', child: Text('Tabulation ( \\t )')),
                            DropdownMenuItem(value: '|', child: Text('Pipe ( | )')),
                            DropdownMenuItem(value: 'custom', child: Text('Personnalisé...')),
                          ],
                          onChanged: (val) {
                            if (val == 'custom') {
                              setState(() => isCustomCard = true);
                            } else if (val != null) {
                              setState(() {
                                isCustomCard = false;
                                selectedCardDelimiter = val;
                              });
                            }
                          },
                        ),
                        if (isCustomCard) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: customCardController,
                              style: const TextStyle(color: Catppuccin.text),
                              decoration: const InputDecoration(
                                hintText: 'ex: ;;\n---',
                                hintStyle: TextStyle(color: Catppuccin.overlay),
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Aperçu du format généré
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Catppuccin.crust,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Catppuccin.surface0),
                      ),
                      child: Text(
                        'Aperçu : Question$effectiveField'
                        'Réponse${effectiveCard == '\n' ? ' [retour ligne]' : effectiveCard}'
                        'Question$effectiveField'
                        'Réponse...',
                        style: const TextStyle(color: Catppuccin.overlay, fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    KawaiiButton(
                      onPressed: () async {
                        final provider = Provider.of<DeckProvider>(context, listen: false);
                        final csvContent = await provider.exportDeckCsv(
                          deck,
                          delimiter: effectiveField,
                          lineEnding: effectiveCard,
                        );

                        await SharePlus.instance.share(
                          ShareParams(
                            text: csvContent,
                            subject: 'Export ${deck.name}.csv',
                            title: 'Export ${deck.name}',
                          ),
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Partager / Enregistrer le fichier 🚀'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
