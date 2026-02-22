import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';

class FamilySwitcherSheet extends StatefulWidget {
  final String currentWalletId;
  final void Function(String walletId) onSelect;

  const FamilySwitcherSheet({
    super.key,
    required this.currentWalletId,
    required this.onSelect,
  });

  static Future<void> show(
    BuildContext context, {
    required String currentWalletId,
    required void Function(String) onSelect,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FamilySwitcherSheet(
        currentWalletId: currentWalletId,
        onSelect: onSelect,
      ),
    );
  }

  @override
  State<FamilySwitcherSheet> createState() => _FamilySwitcherSheetState();
}

class _FamilySwitcherSheetState extends State<FamilySwitcherSheet> {
  final _nameCtrl = TextEditingController();
  bool _showAddForm = false;
  String _selectedEmoji = '👨‍👩‍👧';

  final _emojis = ['👨‍👩‍👧', '👨‍👩‍👦', '👥', '🏠', '💼', '🎓', '❤️', '🌟'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final all = [personalWallet, ...familyWallets];

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Switch Wallet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SizedBox(height: 16),

                // Wallet list
                ...all.map((w) {
                  final isSel = w.id == widget.currentWalletId;
                  return GestureDetector(
                    onTap: () {
                      widget.onSelect(w.id);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: isSel
                            ? LinearGradient(colors: w.gradient)
                            : null,
                        color: isSel
                            ? null
                            : (isDark
                                  ? const Color(0xFF16213E)
                                  : const Color(0xFFF5F6FA)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSel
                              ? Colors.transparent
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(w.emoji, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    fontFamily: 'Nunito',
                                    color: isSel
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.white
                                              : const Color(0xFF1A1A2E)),
                                  ),
                                ),
                                Text(
                                  'Balance: ₹${w.balance >= 1000 ? "${(w.balance / 1000).toStringAsFixed(1)}K" : w.balance.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSel
                                        ? Colors.white70
                                        : const Color(0xFF8E8EA0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSel)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 8),

                // Add family toggle
                if (!_showAddForm)
                  GestureDetector(
                    onTap: () => setState(() => _showAddForm = true),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.4),
                          width: 1.5,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Add New Family / Group',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  _AddFamilyForm(
                    nameCtrl: _nameCtrl,
                    selectedEmoji: _selectedEmoji,
                    emojis: _emojis,
                    onEmojiSelect: (e) => setState(() => _selectedEmoji = e),
                    onCancel: () => setState(() {
                      _showAddForm = false;
                      _nameCtrl.clear();
                    }),
                    onAdd: () {
                      if (_nameCtrl.text.trim().isEmpty) return;
                      final newId = 'f${familyWallets.length + 1}';
                      final ci =
                          familyWallets.length %
                          AppColors.familyGradients.length;
                      familyWallets.add(
                        WalletModel(
                          id: newId,
                          name: _nameCtrl.text.trim(),
                          emoji: _selectedEmoji,
                          isPersonal: false,
                          cashIn: 0,
                          cashOut: 0,
                          onlineIn: 0,
                          onlineOut: 0,
                          gradient: AppColors.familyGradients[ci],
                        ),
                      );
                      widget.onSelect(newId);
                      Navigator.pop(context);
                    },
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddFamilyForm extends StatelessWidget {
  final TextEditingController nameCtrl;
  final String selectedEmoji;
  final List<String> emojis;
  final void Function(String) onEmojiSelect;
  final VoidCallback onCancel, onAdd;

  const _AddFamilyForm({
    required this.nameCtrl,
    required this.selectedEmoji,
    required this.emojis,
    required this.onEmojiSelect,
    required this.onCancel,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16213E) : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New Family / Group',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 12),

          // Emoji picker
          Wrap(
            spacing: 8,
            children: emojis
                .map(
                  (e) => GestureDetector(
                    onTap: () => onEmojiSelect(e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selectedEmoji == e
                            ? AppColors.primary.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selectedEmoji == e
                              ? AppColors.primary
                              : Colors.transparent,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),

          // Name field
          TextField(
            controller: nameCtrl,
            autofocus: true,
            style: const TextStyle(fontFamily: 'Nunito'),
            decoration: InputDecoration(
              hintText: 'Name (e.g. Singh Family)',
              hintStyle: const TextStyle(fontFamily: 'Nunito'),
              filled: true,
              fillColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontFamily: 'Nunito'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAdd,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Add',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
