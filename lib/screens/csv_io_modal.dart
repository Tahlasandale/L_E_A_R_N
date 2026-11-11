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
    String selectedDelimiter = ',';
    String? lineSeparator;

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
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 24,
              ),
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
                  Row(
                    children: [
                      const Text(
                        'Séparateur : ',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Catppuccin.text),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: selectedDelimiter,
                        dropdownColor: Catppuccin.crust,
                        style: const TextStyle(color: Catppuccin.sky, fontWeight: FontWeight.bold),
                        items: const [
                          DropdownMenuItem(value: ',', child: Text('Virgule ( , )')),
                          DropdownMenuItem(value: ';', child: Text('Point-virgule ( ; )')),
                          DropdownMenuItem(value: '\t', child: Text('Tabulation ( \\t )')),
                          DropdownMenuItem(value: '|', child: Text('Pipe ( | )')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => selectedDelimiter = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                      hintText: 'Colle ton CSV ici...\nEx: sin(0),0\ncos(0),1',
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
                        delimiter: selectedDelimiter,
                        lineSeparator: lineSeparator,
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
            );
          },
        );
      },
    );
  }

  /// Ouvre la modale d'exportation CSV
  static Future<void> showExportModal(BuildContext context, Deck deck) async {
    String selectedDelimiter = ',';

    await showModalBottomSheet(
      context: context,
      backgroundColor: Catppuccin.mantle,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
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
                  Row(
                    children: [
                      const Text(
                        'Séparateur : ',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Catppuccin.text),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: selectedDelimiter,
                        dropdownColor: Catppuccin.crust,
                        style: const TextStyle(color: Catppuccin.sky, fontWeight: FontWeight.bold),
                        items: const [
                          DropdownMenuItem(value: ',', child: Text('Virgule ( , )')),
                          DropdownMenuItem(value: ';', child: Text('Point-virgule ( ; )')),
                          DropdownMenuItem(value: '\t', child: Text('Tabulation ( \\t )')),
                          DropdownMenuItem(value: '|', child: Text('Pipe ( | )')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => selectedDelimiter = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  KawaiiButton(
                    onPressed: () async {
                      final provider = Provider.of<DeckProvider>(context, listen: false);
                      final csvContent = await provider.exportDeckCsv(deck, delimiter: selectedDelimiter);

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
                    child: const Text('Partager / Enregistrer le CSV 🚀'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
