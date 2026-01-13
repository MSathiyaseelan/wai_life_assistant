import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceFormNavigator<T> extends ChangeNotifier {
  final List<T> fieldOrder;
  final Map<T, TextEditingController> controllers;
  final Map<T, FocusNode> focusNodes;

  final SpeechToText _speech = SpeechToText();

  int _activeIndex = 0;
  bool _listening = false;

  VoiceFormNavigator({
    required this.fieldOrder,
    required this.controllers,
    required this.focusNodes,
  });

  // 🔹 Getters
  T get activeField => fieldOrder[_activeIndex];
  bool get isListening => _listening;

  bool isActive(T field) => field == activeField;

  // 🔼 Navigation
  void next() {
    if (_activeIndex < fieldOrder.length - 1) {
      _activeIndex++;
      _focusCurrent();
      notifyListeners();
    }
  }

  void previous() {
    if (_activeIndex > 0) {
      _activeIndex--;
      _focusCurrent();
      notifyListeners();
    }
  }

  void _focusCurrent() {
    final field = activeField;
    if (focusNodes.containsKey(field)) {
      focusNodes[field]!.requestFocus();
    }
  }

  // 🎤 Voice Handling
  Future<void> toggleListening() async {
    if (_listening) {
      stopListening();
    } else {
      await startListening();
    }
  }

  // Future<void> startListening() async {
  //   debugPrint('Starting voice recognition...');
  //   final available = await _speech.initialize();
  //   if (!available) return;

  //   _listening = true;
  //   notifyListeners();
  //   _speech.listen(
  //     onResult: (result) {
  //       debugPrint('Borrow Data: ${result.recognizedWords}');
  //       final field = activeField;
  //       if (controllers.containsKey(field)) {
  //         controllers[field]!.text = result.recognizedWords;
  //       }
  //     },
  //   );
  // }

  Future<void> startListening() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      debugPrint('❌ Microphone permission denied');
      return;
    }

    debugPrint('🎤 Initializing speech engine...');

    final available = await _speech.initialize(
      onStatus: (status) => debugPrint('🎧 Status: $status'),
      onError: (error) => debugPrint('❌ Error: ${error.errorMsg}'),
    );

    debugPrint('🎤 Speech available: $available');
    if (!available) return;

    _listening = true;
    notifyListeners();

    await _speech.listen(
      localeId: 'en_IN',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      listenMode: ListenMode.dictation,
      partialResults: true,
      onResult: (result) {
        debugPrint('🗣 (${result.finalResult}) ${result.recognizedWords}');

        final field = activeField;
        if (controllers.containsKey(field)) {
          controllers[field]!.text = result.recognizedWords;
        }
      },
    );
  }

  void stopListening() {
    if (_speech.isListening) {
      _speech.stop();
    }
    _listening = false;
    notifyListeners();
  }

  void disposeAll() {
    _speech.stop();
    for (final c in controllers.values) {
      c.dispose();
    }
    for (final f in focusNodes.values) {
      f.dispose();
    }
  }
}
