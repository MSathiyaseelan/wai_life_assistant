import 'package:flutter/material.dart';

class PollDetailPage extends StatelessWidget {
  const PollDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Poll')),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _YesNoQuestion(question: 'Will you attend the function?'),
          _SingleChoiceQuestion(
            question: 'Preferred gift type',
            options: ['Money', 'Jewel', 'Gift Card'],
          ),
          _NumberQuestion(question: 'How much can you contribute?'),
        ],
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {},
          child: const Text('Submit Vote'),
        ),
      ),
    );
  }
}

class _YesNoQuestion extends StatefulWidget {
  final String question;

  const _YesNoQuestion({required this.question});

  @override
  State<_YesNoQuestion> createState() => _YesNoQuestionState();
}

class _YesNoQuestionState extends State<_YesNoQuestion> {
  bool? _answer;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.question,
              style: Theme.of(context).textTheme.titleSmall,
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Yes'),
                    selected: _answer == true,
                    onSelected: (_) => setState(() => _answer = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('No'),
                    selected: _answer == false,
                    onSelected: (_) => setState(() => _answer = false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleChoiceQuestion extends StatefulWidget {
  final String question;
  final List<String> options;

  const _SingleChoiceQuestion({required this.question, required this.options});

  @override
  State<_SingleChoiceQuestion> createState() => _SingleChoiceQuestionState();
}

class _SingleChoiceQuestionState extends State<_SingleChoiceQuestion> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.question,
              style: Theme.of(context).textTheme.titleSmall,
            ),

            const SizedBox(height: 8),

            ...widget.options.map(
              (opt) => RadioListTile<String>(
                title: Text(opt),
                value: opt,
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberQuestion extends StatelessWidget {
  final String question;

  const _NumberQuestion({required this.question});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question, style: Theme.of(context).textTheme.titleSmall),

            const SizedBox(height: 8),

            TextFormField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixText: '₹ ',
                hintText: 'Enter amount',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
