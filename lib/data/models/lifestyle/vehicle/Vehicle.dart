import 'VehiclePolicy.dart';
import '../lifestyleItem.dart';

enum VehicleType { car, bike, scooter, ev, other }

enum VehicleOwner { self, family }

class Vehicle extends LifestyleItem {
  final VehicleType vehicleTypes;
  final String vehicleNumber;
  final VehicleOwner owners;
  final String model;

  // Identity
  final String? rcNumber;
  final String? engineNo;
  final String? chassisNo;
  final String? fuelType;
  final DateTime? pucExpiry;

  // Policy
  final VehiclePolicy? policy;
  final String? insuranceProvider;
  final String? policyNumber;
  final DateTime? policyStartDate;
  final DateTime? policyExpiryDate;
  final double? idv;

  Vehicle({
    required super.id,
    required super.name,
    required super.category,
    super.brand,
    super.purchaseDate,
    super.notes,

    required this.vehicleTypes,
    required this.vehicleNumber,
    required this.owners,
    required this.model,

    this.rcNumber,
    this.engineNo,
    this.chassisNo,
    this.fuelType,
    this.pucExpiry,
    this.insuranceProvider,
    this.policy,
    this.policyNumber,
    this.policyStartDate,
    this.policyExpiryDate,
    this.idv,
  });
}
