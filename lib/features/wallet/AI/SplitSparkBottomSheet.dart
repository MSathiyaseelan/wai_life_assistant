import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/wallet/SplitAiIntent.dart';

// Future<SplitGroup?> showSplitSparkBottomSheet(BuildContext context) {
//   return showModalBottomSheet<SplitGroup>(
//     context: context,
//     isScrollControlled: true,
//     backgroundColor: Colors.transparent,
//     builder: (_) => const SplitSparkBottomSheet(),
//   );
// }

class SplitSparkBottomSheet extends StatefulWidget {
  const SplitSparkBottomSheet({super.key});

  @override
  State<SplitSparkBottomSheet> createState() => _SplitSparkBottomSheetState();
}

class _SplitSparkBottomSheetState extends State<SplitSparkBottomSheet> {
  final TextEditingController _controller = TextEditingController();

  /// Mock local contacts (replace later with phone contacts)
  final List<String> _contacts = [
    'Sathiya',
    'Venis',
    'Sandy',
    'Imman',
    'Ravi',
    'Priya',
  ];

  String? _groupName;
  List<String> _participants = [];

  List<String> _mentionSuggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_parseInput);
  }

  ////////////////////////////////////////////////////////////
  /// INPUT PARSING
  ////////////////////////////////////////////////////////////

  void _parseInput() {
    final text = _controller.text;

    _parseGroupName(text);
    _parseParticipants(text);
    _detectMention(text);

    setState(() {});
  }

  void _parseGroupName(String text) {
    String? extracted;

    // 1️⃣ Try quoted format
    final quotedMatch = RegExp(r"'([^']*)'").firstMatch(text);
    if (quotedMatch != null) {
      extracted = quotedMatch.group(1);
    } else {
      // 2️⃣ Try "create group as XYZ"
      final match = RegExp(
        r'create (new )?group (as|named)?\s*([a-zA-Z0-9 ]+)',
        caseSensitive: false,
      ).firstMatch(text);

      if (match != null) {
        extracted = match.group(3);
      }
    }

    if (extracted != null && extracted.trim().isNotEmpty) {
      _groupName = extracted.trim();
    } else {
      _groupName = null;
    }
  }

  void _parseParticipants(String text) {
    final lower = text.toLowerCase();

    if (lower.contains("participants")) {
      final parts = text.split("participants").last;
      final names = parts.split(',');

      _participants = names
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
  }

  ////////////////////////////////////////////////////////////
  /// @ MENTION HANDLING
  ////////////////////////////////////////////////////////////

  void _detectMention(String text) {
    final cursorPos = _controller.selection.baseOffset;
    if (cursorPos <= 0) return;

    final textBeforeCursor = text.substring(0, cursorPos);

    final match = RegExp(r'@(\w*)$').firstMatch(textBeforeCursor);

    if (match != null) {
      final query = match.group(1)!.toLowerCase();

      _mentionSuggestions = _contacts
          .where((c) => c.toLowerCase().contains(query))
          .toList();

      _showSuggestions = true;
    } else {
      _showSuggestions = false;
    }
  }

  void _selectMention(String name) {
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPos);

    final newText =
        textBeforeCursor.replaceAll(RegExp(r'@(\w*)$'), '$name ') +
        text.substring(cursorPos);

    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(offset: newText.length);

    _showSuggestions = false;
  }

  ////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Title
            Row(
              children: const [
                Icon(Icons.auto_awesome_rounded, color: Colors.deepPurple),
                SizedBox(width: 8),
                Text(
                  "Spark - Create Group",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// Input Field
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    "Create group as 'Ooty Trip' with participants @Sathiya, @Venis",
                border: OutlineInputBorder(),
              ),
            ),

            if (_showSuggestions) ...[
              const SizedBox(height: 10),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: colors.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  itemCount: _mentionSuggestions.length,
                  itemBuilder: (_, index) {
                    final name = _mentionSuggestions[index];
                    return ListTile(
                      title: Text(name),
                      onTap: () => _selectMention(name),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 20),

            /// 🔥 What I Understand (Redesigned for Split)
            if (_groupName != null || _participants.isNotEmpty)
              _UnderstandingCard(
                groupName: _groupName,
                participants: _participants,
              ),

            const SizedBox(height: 20),

            /// Create Button
            ElevatedButton(
              onPressed: (_groupName != null && _groupName!.isNotEmpty)
                  ? () {
                      final intent = SplitAiIntent(
                        groupName: _groupName!.trim(),
                        participants: _participants,
                      );

                      Navigator.pop(context, intent);
                    }
                  : null,
              child: const Text("Create Group"),
            ),
          ],
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// WHAT I UNDERSTAND CARD
////////////////////////////////////////////////////////////

class _UnderstandingCard extends StatelessWidget {
  final String? groupName;
  final List<String> participants;

  const _UnderstandingCard({
    required this.groupName,
    required this.participants,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "What I understand",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (groupName != null) Text("• Create group named \"$groupName\""),
          if (participants.isNotEmpty)
            Text("• Add participants: ${participants.join(', ')}"),
        ],
      ),
    );
  }
}
