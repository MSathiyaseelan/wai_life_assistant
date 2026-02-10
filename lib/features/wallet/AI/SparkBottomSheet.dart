import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/wallet/AiIntent.dart';
import 'handleAiIntent.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:wai_life_assistant/data/models/wallet/WalletTransaction.dart';

class SparkBottomSheet extends StatefulWidget {
  const SparkBottomSheet({super.key});

  @override
  State<SparkBottomSheet> createState() => _SparkBottomSheetState();
}

class _SparkBottomSheetState extends State<SparkBottomSheet> {
  final controller = TextEditingController();
  AiIntent? parsedIntent;

  //Speech to Text
  final SpeechToText _speech = SpeechToText();
  bool isListening = false;
  bool isLoadingAi = false;
  String spokenText = '';
  //AiIntent? parsedIntent;

  Future<void> _onTapToSpeak() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        debugPrint('🎧 status: $status');
      },
      onError: (error) {
        debugPrint('❌ error: ${error.errorMsg}');
      },
    );

    if (!available) return;

    setState(() {
      isListening = true;
      spokenText = ''; // clear only on start
      parsedIntent = null;
    });

    await _speech.listen(
      localeId: 'en_IN',
      listenMode: ListenMode.dictation,
      partialResults: true,
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 30),
      onResult: (result) {
        debugPrint(
          '🎙️ "${result.recognizedWords}" final=${result.finalResult}',
        );

        // 🔥 ALWAYS update spokenText
        setState(() {
          spokenText = result.recognizedWords;
        });

        // If engine decides it's final
        if (result.finalResult) {
          _onSpeechComplete(fromFinalResult: true);
        }
      },
    );
  }

  Future<void> _onSpeechComplete({bool fromFinalResult = false}) async {
    debugPrint('🛑 Speech complete (final=$fromFinalResult)');
    debugPrint('📝 Final spokenText: "$spokenText"');

    await _speech.stop();

    setState(() {
      isListening = false;
      isLoadingAi = true;
      // ❌ DO NOT clear spokenText here
    });

    if (spokenText.trim().isEmpty) {
      debugPrint('⚠️ Empty speech');
      setState(() => isLoadingAi = false);
      return;
    }

    // Later: AI parsing
    // final json = await GeminiService().parseWalletIntent(spokenText);

    setState(() {
      isLoadingAi = false;
    });
  }

  Future<void> _stopListening() async {
    debugPrint('🛑 User stopped');
    debugPrint('📝 Captured so far: "$spokenText"');

    await _speech.stop();

    setState(() {
      isListening = false;
    });

    // 🔥 Treat manual stop as final
    if (spokenText.trim().isNotEmpty) {
      _onSpeechComplete(fromFinalResult: false);
    }
  }

  void _parseInput() {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    String _capitalize(String value) {
      return value[0].toUpperCase() + value.substring(1);
    }

    //   //Amount Extraction
    double? _extractAmount(String text) {
      final match = RegExp(
        r'(?:₹\s*)?(\d{1,9}(?:,\d{3})*(?:\.\d{1,2})?)',
      ).firstMatch(text);
      return match != null
          ? double.tryParse(match.group(1)!.replaceAll(',', ''))
          : 0.0;
    }

    //   //Payment Mode Detection
    PaymentMode? _extractPaymentMode(String text) {
      final paymentMode = text.toLowerCase();
      final matches = <PaymentMode>[];

      const paymentKeywords = {
        PaymentMode.cash: [
          'cash',
          'money',
          'பணம்',
          'காசு',
          'efectivo',
          'espèces',
        ],
        PaymentMode.upi: ['upi', 'gpay', 'phonepe', 'paytm', 'bhim'],
        PaymentMode.card: [
          'card',
          'credit card',
          'debit card',
          'visa',
          'mastercard',
          'amex',
        ],
        PaymentMode.bankTransfer: [
          'bank transfer',
          'wire',
          'neft',
          'rtgs',
          'imps',
          'sepa',
          'swift',
        ],
        PaymentMode.wallet: [
          'paypal',
          'apple pay',
          'google wallet',
          'amazon pay',
          'alipay',
          'wechat pay',
        ],
      };

      paymentKeywords.forEach((mode, keywords) {
        for (final k in keywords) {
          if (RegExp(r'\b' + RegExp.escape(k) + r'\b').hasMatch(text)) {
            matches.add(mode);
            break;
          }
        }
      });

      if (matches.length == 1) return matches.first;
      return null; // ambiguous or none
    }

    //   //Action Type Detection (Expense vs Income)
    AiIntentType _extractIntentType(String text) {
      final intentType = text.toLowerCase();

      if (intentType.contains('create') && intentType.contains('group')) {
        return AiIntentType.createGroup;
      }

      if (intentType.contains('split')) return AiIntentType.addToGroup;

      if (intentType.contains('gave') ||
          intentType.contains('koduthen') ||
          intentType.contains('lend')) {
        return AiIntentType.lend;
      }

      if (text.contains('borrow') || text.contains('vaanginen')) {
        return AiIntentType.borrow;
      }

      if (text.contains('receive') || text.contains('get')) {
        return AiIntentType.addIncome;
      }

      // Default fallback
      return AiIntentType.addExpense;
    }

    //   //Paid By Detection
    String? _extractPaidBy(String text) {
      final t = text.toLowerCase().trim();

      // 1️⃣ Self-paid detection (high confidence only)
      final selfPatterns = [
        r'\bi paid\b',
        r'\bpaid by me\b',
        r'\bpaid myself\b',
        r'\bnaan pay\b',
        r'\bnaan paid\b',
      ];

      for (final pattern in selfPatterns) {
        if (RegExp(pattern).hasMatch(t)) {
          return 'You';
        }
      }

      // 2️⃣ Name-based patterns (common sentence orders)
      final namePatterns = [
        // Ravi paid / Ravi pay
        r'\b([a-z]+)\s+(paid|pay|payed)\b',

        // Ravi has paid
        r'\b([a-z]+)\s+has\s+paid\b',

        // Paid by Ravi
        r'\bpaid\s+by\s+([a-z]+)\b',

        // Paid Ravi (rare but possible)
        r'\bpaid\s+([a-z]+)\b',
      ];

      for (final pattern in namePatterns) {
        final match = RegExp(pattern).firstMatch(t);
        if (match != null) {
          return _capitalize(match.group(1)!);
        }
      }

      return null; // unknown or ambiguous
    }

    //   //Detect Participants (for group expenses)
    List<String> _extractParticipants(String text) {
      final t = text.toLowerCase();
      final result = <String>{};

      // 1️⃣ Known people (later load from DB)
      final knownNames = ['ravi', 'arun', 'meena', 'sandy', 'imman', 'venis'];

      // Match names safely using word boundaries
      for (final name in knownNames) {
        final regex = RegExp(r'\b' + RegExp.escape(name) + r'\b');
        if (regex.hasMatch(t)) {
          result.add(_capitalize(name));
        }
      }

      // 2️⃣ Self references (high confidence only)
      final selfPatterns = [r'\bme\b', r'\bmyself\b', r'\bi\b', r'\bnaan\b'];

      for (final p in selfPatterns) {
        if (RegExp(p).hasMatch(t)) {
          result.add('You');
          break;
        }
      }

      return result.toList();
    }

    String? _extractGroupHint(String text) {
      final t = text.toLowerCase().trim();

      final groupKeywords = <String, List<String>>{
        'Goa Trip': ['goa', 'goa trip'],
        'Office': ['office', 'work', 'team'],
        'Trip': ['trip', 'travel', 'tour'],
      };

      for (final entry in groupKeywords.entries) {
        for (final keyword in entry.value) {
          final regex = RegExp(r'\b' + RegExp.escape(keyword) + r'\b');
          if (regex.hasMatch(t)) {
            return entry.key;
          }
        }
      }

      return null;
    }

    //   //Category Detection
    ExpenseCategory? _extractCategory(String text) {
      final t = text.toLowerCase().trim();

      final categoryKeywords = <ExpenseCategory, List<String>>{
        ExpenseCategory.food: [
          'food',
          'lunch',
          'dinner',
          'breakfast',
          'hotel',
          'restaurant',
          'meal',
          'biriyani',
          'pizza',
          'tea',
          'coffee',
        ],
        ExpenseCategory.travel: [
          'trip',
          'travel',
          'goa',
          'bus',
          'train',
          'flight',
          'cab',
          'taxi',
          'uber',
          'ola',
        ],
        ExpenseCategory.shopping: [
          'shopping',
          'dress',
          'clothes',
          'shirt',
          'pant',
          'jeans',
          'mall',
          'amazon',
          'flipkart',
        ],
        ExpenseCategory.fuel: ['fuel', 'petrol', 'diesel', 'gas', 'cng'],
        ExpenseCategory.entertainment: [
          'movie',
          'cinema',
          'netflix',
          'spotify',
          'game',
          'concert',
        ],
        ExpenseCategory.groceries: [
          'grocery',
          'groceries',
          'vegetables',
          'fruits',
          'milk',
          'supermarket',
        ],
        ExpenseCategory.rent: ['rent', 'house rent', 'room rent'],
        ExpenseCategory.utilities: [
          'electricity',
          'current bill',
          'water bill',
          'gas bill',
          'internet',
          'wifi',
          'mobile bill',
        ],
        ExpenseCategory.medical: [
          'medical',
          'medicine',
          'hospital',
          'doctor',
          'pharmacy',
        ],
      };

      for (final entry in categoryKeywords.entries) {
        for (final keyword in entry.value) {
          final regex = RegExp(r'\b' + RegExp.escape(keyword) + r'\b');
          if (regex.hasMatch(t)) {
            return entry.key;
          }
        }
      }

      return ExpenseCategory.others;
    }

    //   //Date Detection (Today, Yesterday, Specific Date)
    DateTime detectDate(String text) {
      final t = text.toLowerCase().trim();
      final now = DateTime.now();

      // 1️⃣ Relative keywords
      if (RegExp(r'\byesterday\b').hasMatch(t)) {
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 1));
      }

      if (RegExp(r'\btoday\b').hasMatch(t)) {
        return DateTime(now.year, now.month, now.day);
      }

      if (RegExp(r'\btomorrow\b').hasMatch(t)) {
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).add(const Duration(days: 1));
      }

      // 2️⃣ X days ago
      final daysAgoMatch = RegExp(r'\b(\d+)\s+days?\s+ago\b').firstMatch(t);
      if (daysAgoMatch != null) {
        final days = int.parse(daysAgoMatch.group(1)!);
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: days));
      }

      // 3️⃣ Absolute date: 12 jan / 12 january
      final monthMap = {
        'jan': 1,
        'january': 1,
        'feb': 2,
        'february': 2,
        'mar': 3,
        'march': 3,
        'apr': 4,
        'april': 4,
        'may': 5,
        'jun': 6,
        'june': 6,
        'jul': 7,
        'july': 7,
        'aug': 8,
        'august': 8,
        'sep': 9,
        'september': 9,
        'oct': 10,
        'october': 10,
        'nov': 11,
        'november': 11,
        'dec': 12,
        'december': 12,
      };

      final dateMatch = RegExp(
        r'\b(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|january|february|march|april|june|july|august|september|october|november|december)\b',
      ).firstMatch(t);

      if (dateMatch != null) {
        final day = int.parse(dateMatch.group(1)!);
        final month = monthMap[dateMatch.group(2)!]!;

        // assume current year
        return DateTime(now.year, month, day);
      }

      // 4️⃣ Default: today (safe fallback)
      return DateTime(now.year, now.month, now.day);
    }

    AiIntent parseAiIntent(String input) {
      final text = input.toLowerCase();

      final amount = _extractAmount(text);
      final paymentMode = _extractPaymentMode(text);
      final intentType = _extractIntentType(text);
      final paidBy = _extractPaidBy(text);
      final groupName = _extractGroupHint(text);
      final participants = _extractParticipants(text);
      final category = _extractCategory(text);

      return AiIntent(
        type: intentType,
        amount: amount ?? 0.0,
        paymentMode: paymentMode,
        paidBy: paidBy,
        groupName: groupName,
        participants: participants,
        category: category,
        splitType: intentType == AiIntentType.addExpense && groupName != null
            ? SplitType.equal
            : null,
      );
    }

    //   // TEMP: replace with real parser later
    setState(() {
      parsedIntent = parseAiIntent(text);
    });
  }

  // void _parseInput() {
  //   final text = controller.text.trim();
  //   if (text.isEmpty) return;

  //   setState(() {
  //     parsedIntent = AiIntent.mock(text);
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "✨ Spark Assistant",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "Tell me what happened",
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: controller,
            onSubmitted: (_) => _parseInput(),
            decoration: InputDecoration(
              hintText: "Goa trip taxi 800 Ravi paid",
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: _parseInput,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // TextButton.icon(
          //   onPressed: () {},
          //   icon: const Icon(Icons.mic),
          //   label: const Text("Tap to speak"),
          // ),
          TextButton.icon(
            onPressed: isListening ? _stopListening : _onTapToSpeak,
            icon: Icon(
              isListening ? Icons.stop : Icons.mic,
              color: isListening ? Colors.redAccent : null,
            ),
            label: Text(isListening ? "Listening…" : "Tap to speak"),
          ),

          const SizedBox(height: 16),

          if (parsedIntent != null) ...[
            const Divider(),
            _AiPreview(intent: parsedIntent!),
          ],
        ],
      ),
    );
  }
}

class _AiPreview extends StatelessWidget {
  final AiIntent intent;

  const _AiPreview({required this.intent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "What I understood",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        _row("Action", intent.type.name),
        if (intent.groupName != null) _row("Group", intent.groupName!),
        if (intent.amount != null) _row("Amount", "₹${intent.amount}"),
        if (intent.paidBy != null) _row("Paid by", intent.paidBy!),
        if (intent.splitType != null) _row("Split", intent.splitType!.name),
        if (intent.category != null) _row("Category", intent.category!.name),
        if (intent.participants.isNotEmpty)
          _row("Participants", intent.participants.join(", ")),
        if (intent.paymentMode != null)
          _row("Payment Mode", intent.paymentMode!.name),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  final intents = AiIntent(
                    type: intent.type,
                    //walletType: detectedWalletType,
                    //action: detectedAction,
                    amount: intent.amount,
                    purpose: intent.purpose,
                    category: intent.category,
                    //notes: detectedNotes,
                  );

                  Navigator.pop(context, intents); // ✅ RETURN INTENT
                },
                child: const Text("Confirm"),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(onPressed: () {}, child: const Text("Edit")),
          ],
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
