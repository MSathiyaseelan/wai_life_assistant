import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/wallet/AiIntent.dart';

void handleAiIntent(BuildContext context, AiIntent intent) {
  switch (intent.type) {
    case AiIntentType.addExpense:
      //_handleExpense(context, intent);
      break;

    case AiIntentType.createGroup:
      //_handleCreateGroup(context, intent);
      break;

    case AiIntentType.lend:
    case AiIntentType.borrow:
      //_handleLendBorrow(context, intent);
      break;

    case AiIntentType.addIncome:
      // Handle add income intent
      break;

    case AiIntentType.requestMoney:
      // Handle request money intent
      break;

    case AiIntentType.addToGroup:
      // Handle add to group intent
      break;
  }
}
