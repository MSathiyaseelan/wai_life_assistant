import '../../enum/gifttype.dart';
import '../../enum/giftcontributiontype.dart';

class GiftedItem {
  final String person;
  final GiftType giftType;
  final ContributionType contributionType;

  final double? amount;
  final String? itemName;
  final String? giftCardBrand;

  final String functionName;
  final DateTime date;

  GiftedItem({
    required this.person,
    required this.giftType,
    required this.contributionType,
    this.amount,
    this.itemName,
    this.giftCardBrand,
    required this.functionName,
    required this.date,
  });
}
