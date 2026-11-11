import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../providers/deck_provider.dart';
import '../theme/catppuccin.dart';
import '../widgets/kawaii_button.dart';
import 'csv_io_modal.dart';

class DeckDetailScreen extends StatefulWidget {
  final Deck deck;

  const DeckDetailScreen({super.key, required this.deck});

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddCardDialog() {
    final frontController = TextEditingController();
    final backController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Catppuccin.mantle,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Nouvelle Carte 🃏', style: TextStyle(color: Catppuccin.sky, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: frontController,
              maxLines: 1,
              style: const TextStyle(color: Catppuccin.text),
              decoration: const InputDecoration(
                labelText: 'Question (sur une seule ligne)',
                labelStyle: TextStyle(color: Catppuccin.overlay),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: backController,
              maxLines: 1,
              style: const TextStyle(color: Catppuccin.text),
              decoration: const InputDecoration(
                labelText: 'Réponse (sur une seule ligne)',
                labelStyle: TextStyle(color: Catppuccin.overlay),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Catppuccin.overlay)),
          ),
          KawaiiButton(
            height: 42,
            width: 120,
            onPressed: () async {
              final front = frontController.text.trim();
              final back = backController.text.trim();
              if (front.isNotEmpty && back.isNotEmpty) {
                final provider = Provider.of<DeckProvider>(context, listen: false);
                await provider.addCard(
                  deck: widget.deck,
                  front: front,
                  back: back,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Ajouter ⚡'),
          ),
        ],
      ),
    );
  }

  void _showEditCardDialog(Flashcard card) {
    final frontController = TextEditingController(text: card.front);
    final backController = TextEditingController(text: card.back);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Catppuccin.mantle,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Modifier la Carte ✏️', style: TextStyle(color: Catppuccin.blue, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: frontController,
              maxLines: 1,
              style: const TextStyle(color: Catppuccin.text),
              decoration: const InputDecoration(
                labelText: 'Question',
                labelStyle: TextStyle(color: Catppuccin.overlay),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: backController,
              maxLines: 1,
              style: const TextStyle(color: Catppuccin.text),
              decoration: const InputDecoration(
                labelText: 'Réponse',
                labelStyle: TextStyle(color: Catppuccin.overlay),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Catppuccin.overlay)),
          ),
          KawaiiButton(
            height: 42,
            width: 120,
            onPressed: () async {
              final front = frontController.text.trim();
              final back = backController.text.trim();
              if (front.isNotEmpty && back.isNotEmpty) {
                card.front = front;
                card.back = back;
                final provider = Provider.of<DeckProvider>(context, listen: false);
                await provider.updateCard(card);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deckProvider = Provider.of<DeckProvider>(context);
    final currentDeck = deckProvider.decks.firstWhere(
      (d) => d.id == widget.deck.id,
      orElse: () => widget.deck,
    );

    final cards = currentDeck.allCards.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.front.toLowerCase().contains(_searchQuery) ||
          c.back.toLowerCase().contains(_searchQuery);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentDeck.name,
          style: const TextStyle(fontWeight: FontWeight.w900, color: Catppuccin.sky),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, color: Catppuccin.sky),
            tooltip: 'Importer CSV',
            onPressed: () => CsvIoModal.showImportModal(context, currentDeck),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Catppuccin.blue),
            tooltip: 'Exporter CSV',
            onPressed: () => CsvIoModal.showExportModal(context, currentDeck),
          ),
        ],
      ),
      body: Column(
        children: [
          // Bandeau d'information & bascule de mode
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final newMode = currentDeck.mode == FsrsMode.intensiveMinutes
                        ? FsrsMode.longTermDays
                        : FsrsMode.intensiveMinutes;
                    await deckProvider.switchDeckMode(currentDeck, newMode);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Catppuccin.mantle,
                          content: Text(
                            newMode == FsrsMode.intensiveMinutes
                                ? '⚡ Paquet basculé en Mode Colles (minutes) !'
                                : '📆 Paquet basculé en Mode Long Terme (jours) !',
                            style: const TextStyle(color: Catppuccin.sky, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: currentDeck.mode == FsrsMode.intensiveMinutes
                          ? Catppuccin.peach.withValues(alpha: 0.15)
                          : Catppuccin.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: currentDeck.mode == FsrsMode.intensiveMinutes
                            ? Catppuccin.peach
                            : Catppuccin.blue,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentDeck.mode == FsrsMode.intensiveMinutes ? 'Mode Colles ⚡' : 'Mode Long Terme 📆',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: currentDeck.mode == FsrsMode.intensiveMinutes
                                ? Catppuccin.peach
                                : Catppuccin.blue,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.sync, size: 14, color: Catppuccin.subtext),
                      ],
                    ),
                  ),
                ),
                Text(
                  '${cards.length} carte${cards.length > 1 ? 's' : ''}',
                  style: const TextStyle(color: Catppuccin.overlay, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Catppuccin.text),
              decoration: InputDecoration(
                hintText: 'Rechercher une carte...',
                hintStyle: const TextStyle(color: Catppuccin.overlay),
                prefixIcon: const Icon(Icons.search, color: Catppuccin.sky),
                filled: true,
                fillColor: Catppuccin.mantle,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Catppuccin.surface0, width: 2),
                ),
              ),
            ),
          ),
          Expanded(
            child: cards.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'Ce paquet est vide.\nAppuie sur (+) pour ajouter une carte !'
                          : 'Aucun résultat trouvé.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Catppuccin.overlay, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    itemCount: cards.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    itemBuilder: (context, index) {
                      final card = cards[index];

                      return Dismissible(
                        key: ValueKey(card.id),
                        direction: DismissDirection.startToEnd,
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Catppuccin.red,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete, color: Catppuccin.crust),
                        ),
                        onDismissed: (_) {
                          HapticFeedback.lightImpact();
                          deckProvider.deleteCard(card.id);
                        },
                        child: Card(
                          color: Catppuccin.mantle,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Catppuccin.surface0, width: 2),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(
                              card.front,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Catppuccin.text),
                            ),
                            subtitle: Text(
                              card.back,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Catppuccin.sky),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit, size: 20, color: Catppuccin.overlay),
                              onPressed: () => _showEditCardDialog(card),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Catppuccin.blue,
        foregroundColor: Catppuccin.crust,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: _showAddCardDialog,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
