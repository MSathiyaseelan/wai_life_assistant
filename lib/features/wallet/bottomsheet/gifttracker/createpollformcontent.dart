import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/data/enum/pollquestiontype.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/gifttracker/showaddmembersbottomsheet.dart';

class CreatePollFormContent extends StatefulWidget {
  const CreatePollFormContent({super.key});

  @override
  State<CreatePollFormContent> createState() => _CreatePollFormContentState();
}

class _CreatePollFormContentState extends State<CreatePollFormContent> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _functionCtrl = TextEditingController();

  final List<_PollQuestionDraft> _questions = [];
  final List<String> _selectedMembers = [];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _functionCtrl.dispose();
    super.dispose();
  }

  void _openAddMembers() {
    showAddMembersBottomSheet(
      context: context,
      selectedMembers: _selectedMembers,
      onDone: (members) {
        setState(() {
          _selectedMembers
            ..clear()
            ..addAll(members);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Header
          Text('Create Poll', style: textTheme.titleMedium),

          const SizedBox(height: AppSpacing.gapSM),

          /// Poll title
          TextFormField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Poll title'),
            validator: (v) => v == null || v.isEmpty ? 'Enter title' : null,
          ),

          const SizedBox(height: AppSpacing.gapSM),

          /// Function name
          TextFormField(
            controller: _functionCtrl,
            decoration: const InputDecoration(labelText: 'Function name'),
          ),

          const SizedBox(height: AppSpacing.gapMM),

          /// Questions
          Text('Questions', style: textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.gapSS),

          ..._questions.map(_QuestionPreviewTile.new),

          TextButton.icon(
            onPressed: _addQuestion,
            icon: const Icon(Icons.add),
            label: const Text('Add question'),
          ),

          const SizedBox(height: AppSpacing.gapMM),

          /// Members
          Text('Members', style: textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.gapSS),

          Row(
            children: [
              Expanded(
                child: _selectedMembers.isEmpty
                    ? Text(
                        'No members added',
                        style: textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _selectedMembers
                            .map(
                              (m) => Chip(
                                label: Text(m),
                                onDeleted: () {
                                  setState(() => _selectedMembers.remove(m));
                                },
                              ),
                            )
                            .toList(),
                      ),
              ),

              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Add members',
                onPressed: _openAddMembers,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.gapL),

          /// Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.gapSM),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Create'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addQuestion() {
    setState(() {
      _questions.add(
        _PollQuestionDraft(
          question: 'Will you attend?',
          type: PollQuestionType.yesNo,
        ),
      );
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one member')),
      );
      return;
    }

    final pollData = {
      'title': _titleCtrl.text,
      'function': _functionCtrl.text,
      'members': _selectedMembers,
      'questions': _questions,
    };

    debugPrint('Poll Data: $pollData');
    Navigator.pop(context);
  }
}

class _PollQuestionDraft {
  final String question;
  final PollQuestionType type;
  final List<String>? options;

  _PollQuestionDraft({
    required this.question,
    required this.type,
    this.options,
  });
}

class _QuestionPreviewTile extends StatelessWidget {
  final _PollQuestionDraft question;

  const _QuestionPreviewTile(this.question);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(question.question),
      subtitle: Text(question.type.name),
      trailing: const Icon(Icons.drag_handle),
    );
  }
}
