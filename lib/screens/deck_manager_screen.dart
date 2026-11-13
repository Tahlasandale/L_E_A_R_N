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

  void _showEditDeckDialog(BuildContext context, Deck deck) {
    final controller = TextEditingController(text: deck.name);
    FsrsMode selectedMode = deck.mode;
    bool isActive = deck.isActive;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Catppuccin.mantle,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: const Text('Modifier le Paquet ✏️', style: TextStyle(color: Catppuccin.sky, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: Catppuccin.text),
                    decoration: const InputDecoration(
                      labelText: 'Nom du paquet',
                      labelStyle: TextStyle(color: Catppuccin.overlay),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Mode FSRS :', style: TextStyle(color: Catppuccin.subtext, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButton<FsrsMode>(
                    value: selectedMode,
                    dropdownColor: Catppuccin.crust,
                    isExpanded: true,
                    style: const TextStyle(color: Catppuccin.text, fontWeight: FontWeight.bold),
                    items: const [
                      DropdownMenuItem(
                        value: FsrsMode.intensiveMinutes,
                        child: Text('⚡ Mode Colles (intervalles en minutes)'),
                      ),
                      DropdownMenuItem(
                        value: FsrsMode.longTermDays,
                        child: Text('📆 Mode Long terme (intervalles en jours)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => selectedMode = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Paquet Actif', style: TextStyle(color: Catppuccin.text, fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Inclus dans les révisions du tableau de bord', style: TextStyle(color: Catppuccin.overlay, fontSize: 12)),
                    value: isActive,
                    activeColor: Catppuccin.green,
                    onChanged: (val) => setState(() => isActive = val),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler', style: TextStyle(color: Catppuccin.overlay)),
              ),
              KawaiiButton(
                height: 42,
                width: 130,
                onPressed: () async {
                  final newName = controller.text.trim();
                  if (newName.isEmpty) return;

                  final provider = Provider.of<DeckProvider>(context, listen: false);

                  // Renommer si changé
                  if (newName != deck.name) {
                    final success = await provider.renameDeck(deck, newName);
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Catppuccin.red,
                          content: Text('Un paquet avec ce nom existe déjà !', style: TextStyle(color: Catppuccin.crust, fontWeight: FontWeight.bold)),
                        ),
                      );
                      return;
                    }
                  }

                  // Basculer le mode si changé
                  if (selectedMode != deck.mode) {
                    await provider.switchDeckMode(deck, selectedMode);
                  }

                  // Basculer statut actif si changé
                  if (isActive != deck.isActive) {
                    await provider.toggleDeckActive(deck);
                  }

                  if (context.mounted) Navigator.pop(ctx);
                },
                child: const Text('Enregistrer 💾'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _toggleDeckMode(BuildContext context, Deck deck) async {
    HapticFeedback.lightImpact();
    final provider = Provider.of<DeckProvider>(context, listen: false);
    final newMode = deck.mode == FsrsMode.intensiveMinutes
        ? FsrsMode.longTermDays
        : FsrsMode.intensiveMinutes;

    await provider.switchDeckMode(deck, newMode);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Catppuccin.mantle,
          duration: const Duration(seconds: 2),
          content: Text(
            newMode == FsrsMode.intensiveMinutes
                ? '⚡ "${deck.name}" basculé en Mode Colles (minutes) !'
                : '📆 "${deck.name}" basculé en Mode Long Terme (jours) !',
            style: const TextStyle(color: Catppuccin.sky, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  void _toggleDeckActive(BuildContext context, Deck deck) async {
    HapticFeedback.lightImpact();
    final provider = Provider.of<DeckProvider>(context, listen: false);
    await provider.toggleDeckActive(deck);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Catppuccin.mantle,
          duration: const Duration(seconds: 1),
          content: Text(
            deck.isActive
                ? '✅ "${deck.name}" est maintenant ACTIF !'
                : '💤 "${deck.name}" est maintenant INACTIF (exclu des rappels & de l\'accueil).',
            style: TextStyle(
              color: deck.isActive ? Catppuccin.green : Catppuccin.overlay,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
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
                final totalCount = deck.allCards.length;
                final isMinutes = deck.mode == FsrsMode.intensiveMinutes;

                return Opacity(
                  opacity: deck.isActive ? 1.0 : 0.65,
                  child: Card(
                    color: Catppuccin.mantle,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                      side: BorderSide(
                        color: deck.isActive ? Catppuccin.surface0 : Catppuccin.crust,
                        width: 2.5,
                      ),
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
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: deck.isActive ? Catppuccin.text : Catppuccin.subtext,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Badge mode cliquable
                                      GestureDetector(
                                        onTap: () => _toggleDeckMode(context, deck),
                                        child: Container(
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
                                      ),
                                      if (!deck.isActive) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Catppuccin.surface0,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            '💤 Inactif',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Catppuccin.overlay,
                                            ),
                                          ),
                                        ),
                                      ],
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
                            // Bouton Modifier
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Catppuccin.sky),
                              tooltip: 'Modifier / Renommer le paquet',
                              onPressed: () => _showEditDeckDialog(context, deck),
                            ),
                            // Bouton Actif / Inactif
                            IconButton(
                              icon: Icon(
                                deck.isActive ? Icons.visibility : Icons.visibility_off,
                                color: deck.isActive ? Catppuccin.sky : Catppuccin.overlay,
                              ),
                              tooltip: deck.isActive ? 'Rendre inactif' : 'Rendre actif',
                              onPressed: () => _toggleDeckActive(context, deck),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Catppuccin.overlay),
                              tooltip: 'Supprimer le paquet',
                              onPressed: () => _showDeleteDeckDialog(context, deck),
                            ),
                            const Icon(Icons.chevron_right, color: Catppuccin.sky),
                          ],
                        ),
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
