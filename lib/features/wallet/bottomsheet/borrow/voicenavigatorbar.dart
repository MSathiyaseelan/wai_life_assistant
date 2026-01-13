import 'package:flutter/material.dart';
import 'voiceformnavigator.dart';

class VoiceNavigatorBar<T> extends StatelessWidget {
  final VoiceFormNavigator<T> navigator;

  const VoiceNavigatorBar({super.key, required this.navigator});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          /// ⬆ Previous field
          IconButton(
            tooltip: 'Previous field',
            onPressed: navigator.previous,
            icon: const Icon(Icons.keyboard_arrow_up),
          ),

          /// 🎤 Mic button
          FloatingActionButton.small(
            heroTag: null,
            backgroundColor: navigator.isListening
                ? colorScheme.primary
                : colorScheme.secondaryContainer,
            foregroundColor: navigator.isListening
                ? colorScheme.onPrimary
                : colorScheme.onSecondaryContainer,
            onPressed: navigator.toggleListening,
            child: Icon(
              navigator.isListening ? Icons.mic : Icons.mic_none,
              color: navigator.isListening ? Colors.red : null,
            ),
          ),

          /// ⬇ Next field
          IconButton(
            tooltip: 'Next field',
            onPressed: navigator.next,
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
        ],
      ),
    );
  }
}
