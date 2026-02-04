class VehiclePolicy {
  String provider;
  String policyNumber;
  InsuranceType type;
  DateTime startDate;
  DateTime expiryDate;
  double? idvValue;
  String? documentPath; // local file path / URL

  VehiclePolicy({
    required this.provider,
    required this.policyNumber,
    required this.type,
    required this.startDate,
    required this.expiryDate,
    this.idvValue,
    this.documentPath,
  });
}

enum InsuranceType { comprehensive, thirdParty }
