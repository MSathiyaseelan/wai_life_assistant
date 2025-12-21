import 'package:flutter/material.dart';

class TwoScreen extends StatefulWidget {
  const TwoScreen({super.key});

  @override
  State<TwoScreen> createState() => _TwoScreenState();
}

class _TwoScreenState extends State<TwoScreen> {
  @override
  Widget build(BuildContext context) {
    return Column(children: [Text('Two Screen')]);
  }
}
