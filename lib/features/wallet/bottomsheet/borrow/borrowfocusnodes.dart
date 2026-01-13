import 'package:flutter/material.dart';
import '../../../../data/enum/borrowfields.dart';

final Map<BorrowField, TextEditingController> controllers = {
  BorrowField.person: TextEditingController(),
  BorrowField.amount: TextEditingController(),
  BorrowField.description: TextEditingController(),
  BorrowField.witness: TextEditingController(),
};

final Map<BorrowField, FocusNode> focusNodes = {
  BorrowField.person: FocusNode(),
  BorrowField.amount: FocusNode(),
  BorrowField.description: FocusNode(),
  BorrowField.witness: FocusNode(),
};

//int _activeIndex = 0;

final fieldsOrder = [
  BorrowField.person,
  BorrowField.amount,
  BorrowField.description,
  BorrowField.returnDate,
  BorrowField.interestType,
  BorrowField.witness,
];
