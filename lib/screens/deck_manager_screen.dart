import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/deck.dart';
import '../providers/deck_provider.dart';
import '../theme/catppuccin.dart';
import '../widgets/kawaii_button.dart';
import 'deck_detail_screen.dart';

class DeckManagerScreen extends StatelessWidget {
  const DeckManagerScreen({super.key});

  void _showCreateDeckDialog(BuildContext context) {
    final controller = TextEditingController();
    FsrsMode selectedMode = FsrsMode.intensiveMinutes;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Catppuccin.mantle,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: const Text('Nouveau Paquet 📚', style: TextStyle(color: Catppuccin.sky, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  style: const TextStyle(color: Catppuccin.text),
                  decoration: const InputDecoration(
                    labelText: 'Nom du paquet (ex: Trigonométrie, Kanji...)',
                    labelStyle: TextStyle(color: Catppuccin.overlay),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButton<FsrsMode>(
                  value: selectedMode,
                  dropdownColor: Catppuccin.crust,
                  style: const TextStyle(color: Catppuccin.text, fontWeight: FontWeight.bold),
                  items: const [
                    DropdownMenuItem(
                      value: FsrsMode.intensiveMinutes,
                      child: Text('Mode Colles (Minutes)'),
                    ),
                    DropdownMenuItem(
                      value: FsrsMode.longTermDays,
                      child: Text('Mode Long terme (Jours)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => selectedMode = val);
                  },
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
                width: 110,
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isNotEmpty) {
                    final provider = Provider.of<DeckProvider>(context, listen: false);
                    await provider.createDeck(name, mode: selectedMode);
                    if (context.mounted) Navigator.pop(ctx);
                  }
                },
                child: const Text('Créer ⚡'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteDeckDialog(BuildContext context, Deck deck) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Catppuccin.mantle,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Supprimer le paquet ?', style: TextStyle(color: Catppuccin.red, fontWeight: FontWeight.bold)),
        content: Text(
          'Attention : toutes les cartes du paquet "${deck.name}" seront définitivement supprimées.',
          style: const TextStyle(color: Catppuccin.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Catppuccin.overlay)),
          ),
          TextButton(
            onPressed: () async {
              HapticFeedback.lightImpact();
              final provider = Provider.of<DeckProvider>(context, listen: false);
              await provider.deleteDeck(deck.id);
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('Supprimer 🗑️', style: TextStyle(color: Catppuccin.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deckProvider = Provider.of<DeckProvider>(context);
    final decks = deckProvider.decks;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mes Paquets 📚',
          style: TextStyle(fontWeight: FontWeight.w900, color: Catppuccin.sky),
        ),
      ),
      body: decks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('(*^‿^*)', style: TextStyle(fontSize: 42, color: Catppuccin.sky)),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucun paquet pour le moment !',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Catppuccin.text),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Crée ton premier paquet pour y ajouter des flashcards.',
                    style: TextStyle(color: Catppuccin.overlay, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  KawaiiButton(
                    width: 220,
                    onPressed: () => _showCreateDeckDialog(context),
                    child: const Text('➕ Créer un paquet'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: decks.length,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              itemBuilder: (context, index) {
                final deck = decks[index];
                final dueCount = deckProvider.getDueCardsCountForDeck(deck);
                final totalCount = deck.cards.length;
                final isMinutes = deck.mode == FsrsMode.intensiveMinutes;

                return Card(
                  color: Catppuccin.mantle,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: const BorderSide(color: Catppuccin.surface0, width: 2.5),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeckDetailScreen(deck: deck),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        deck.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Catppuccin.text,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isMinutes ? Catppuccin.peach.withValues(alpha: 0.15) : Catppuccin.blue.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isMinutes ? Catppuccin.peach : Catppuccin.blue,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Text(
                                        isMinutes ? 'Colles ⚡' : 'Long terme 📆',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isMinutes ? Catppuccin.peach : Catppuccin.blue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$totalCount cartes • $dueCount à réviser',
                                  style: const TextStyle(
                                    color: Catppuccin.subtext,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Catppuccin.overlay),
                            onPressed: () => _showDeleteDeckDialog(context, deck),
                          ),
                          const Icon(Icons.chevron_right, color: Catppuccin.sky),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Catppuccin.blue,
        foregroundColor: Catppuccin.crust,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: () => _showCreateDeckDialog(context),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
