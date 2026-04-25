import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SHARED
// ─────────────────────────────────────────────────────────────────────────────

class LifeMember {
  final String id, name, emoji;
  const LifeMember({required this.id, required this.name, required this.emoji});
}

const mockLifeMembers = [
  LifeMember(id: 'me', name: 'Me', emoji: '🧑'),
  LifeMember(id: 'dad', name: 'Dad', emoji: '👨'),
  LifeMember(id: 'mom', name: 'Mom', emoji: '👩'),
  LifeMember(id: 'son', name: 'Arjun', emoji: '👦'),
  LifeMember(id: 'dau', name: 'Priya', emoji: '👧'),
];

// ─────────────────────────────────────────────────────────────────────────────
// MY GARAGE
// ─────────────────────────────────────────────────────────────────────────────

enum VehicleType {
  twoWheeler('🏍️', '2 Wheeler'),
  car('🚗', '4 Wheeler'),
  bicycle('🚲', 'Bicycle'),
  truck('🚛', 'Truck/Van'),
  ev('⚡', 'Electric'),
  auto('🛺', 'Auto');

  final String emoji, label;
  const VehicleType(this.emoji, this.label);
}

class VehicleInsurance {
  String id, provider, policyNo, type;
  DateTime startDate, expiryDate;
  double premium;
  bool reminderSet;
  VehicleInsurance({
    required this.id,
    required this.provider,
    required this.policyNo,
    required this.type,
    required this.startDate,
    required this.expiryDate,
    required this.premium,
    this.reminderSet = true,
  });
}

class VehicleService {
  String id, serviceName, garage;
  DateTime serviceDate;
  double? cost;
  String? notes;
  DateTime? nextDue;
  VehicleService({
    required this.id,
    required this.serviceName,
    required this.garage,
    required this.serviceDate,
    this.cost,
    this.notes,
    this.nextDue,
  });
}

class RepairTask {
  String id, title;
  bool done;
  String? notes;
  DateTime? plannedDate;
  double? estimatedCost;
  RepairTask({
    required this.id,
    required this.title,
    this.done = false,
    this.notes,
    this.plannedDate,
    this.estimatedCost,
  });
}

class VehicleModel {
  String id, name, walletId;
  VehicleType type;
  String? make,
      model,
      year,
      regNo,
      chassisNo,
      engineNo,
      fuelType,
      color,
      ownerId;
  List<VehicleInsurance> policies;
  List<VehicleService> services;
  List<RepairTask> repairs;
  VehicleModel({
    required this.id,
    required this.name,
    required this.walletId,
    required this.type,
    this.make,
    this.model,
    this.year,
    this.regNo,
    this.chassisNo,
    this.engineNo,
    this.fuelType,
    this.color,
    this.ownerId = 'me',
    List<VehicleInsurance>? policies,
    List<VehicleService>? services,
    List<RepairTask>? repairs,
  }) : policies = policies ?? [],
       services = services ?? [],
       repairs = repairs ?? [];
}

final List<VehicleModel> mockVehicles = [
  VehicleModel(
    id: 'v1',
    name: 'Honda Activa',
    walletId: 'personal',
    type: VehicleType.twoWheeler,
    make: 'Honda',
    model: 'Activa 6G',
    year: '2021',
    regNo: 'TN09AB1234',
    fuelType: 'Petrol',
    color: 'Pearl White',
    ownerId: 'me',
    policies: [
      VehicleInsurance(
        id: 'p1',
        provider: 'Bajaj Allianz',
        policyNo: 'BA123456',
        type: 'Comprehensive',
        startDate: DateTime(2024, 4, 1),
        expiryDate: DateTime(2025, 3, 31),
        premium: 3200,
      ),
    ],
    services: [
      VehicleService(
        id: 's1',
        serviceName: '6-Month Service',
        garage: 'Honda Service Center',
        serviceDate: DateTime(2024, 10, 12),
        cost: 1850,
        nextDue: DateTime(2025, 4, 12),
      ),
    ],
  ),
  VehicleModel(
    id: 'v2',
    name: 'Maruti Swift',
    walletId: 'personal',
    type: VehicleType.car,
    make: 'Maruti Suzuki',
    model: 'Swift ZXI',
    year: '2020',
    regNo: 'TN09CD5678',
    fuelType: 'Petrol',
    color: 'Metallic Blue',
    ownerId: 'dad',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// MY WARDROBE
// ─────────────────────────────────────────────────────────────────────────────

enum ClothingGender { male, female, kids, unisex }

enum ClothingCategory {
  topwear('👕', 'Topwear'),
  bottomwear('👖', 'Bottomwear'),
  ethnic('👘', 'Ethnic'),
  footwear('👟', 'Footwear'),
  accessories('💍', 'Accessories'),
  sportswear('🏃', 'Sportswear'),
  formal('👔', 'Formal'),
  innerwear('🩲', 'Innerwear');

  final String emoji, label;
  const ClothingCategory(this.emoji, this.label);
}

class ClothingItem {
  String id, memberId, name, walletId;
  ClothingCategory category;
  ClothingGender gender;
  String? brand, size, color, photoPath, notes;
  bool wishlist;
  String? wishlistSource; // online URL or description
  List<String> matchWith; // ids of matching items
  DateTime addedOn;
  ClothingItem({
    required this.id,
    required this.memberId,
    required this.name,
    required this.walletId,
    required this.category,
    required this.gender,
    this.brand,
    this.size,
    this.color,
    this.photoPath,
    this.notes,
    this.wishlist = false,
    this.wishlistSource,
    List<String>? matchWith,
    DateTime? addedOn,
  }) : matchWith = matchWith ?? [],
       addedOn = addedOn ?? DateTime.now();
}

class OutfitLog {
  String id, memberId;
  List<String> itemIds;
  DateTime date;
  String? notes;
  OutfitLog({
    required this.id,
    required this.memberId,
    required this.itemIds,
    required this.date,
    this.notes,
  });
}

final List<ClothingItem> mockClothes = [
  ClothingItem(
    id: 'c1',
    memberId: 'me',
    walletId: 'personal',
    name: 'White Oxford Shirt',
    category: ClothingCategory.topwear,
    gender: ClothingGender.male,
    brand: 'Arrow',
    size: 'L',
    color: 'White',
    matchWith: ['c2'],
  ),
  ClothingItem(
    id: 'c2',
    memberId: 'me',
    walletId: 'personal',
    name: 'Navy Chinos',
    category: ClothingCategory.bottomwear,
    gender: ClothingGender.male,
    brand: 'Levi\'s',
    size: '32',
    color: 'Navy',
    matchWith: ['c1'],
  ),
  ClothingItem(
    id: 'c3',
    memberId: 'me',
    walletId: 'personal',
    name: 'Floral Kurta',
    category: ClothingCategory.ethnic,
    gender: ClothingGender.male,
    brand: 'Manyavar',
    size: 'L',
    color: 'Cream',
  ),
  ClothingItem(
    id: 'c4',
    memberId: 'dau',
    walletId: 'personal',
    name: 'Blue Salwar',
    category: ClothingCategory.ethnic,
    gender: ClothingGender.female,
    brand: 'Fabindia',
    size: 'M',
    color: 'Blue',
  ),
  ClothingItem(
    id: 'wl1',
    memberId: 'me',
    walletId: 'personal',
    name: 'Burgundy Blazer',
    category: ClothingCategory.formal,
    gender: ClothingGender.male,
    wishlist: true,
    wishlistSource: 'Seen at Zara, ₹4,500',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// MY DEVICES
// ─────────────────────────────────────────────────────────────────────────────

enum DeviceCategory {
  phone('📱', 'Phone', Color(0xFF4A9EFF)),
  laptop('💻', 'Laptop', Color(0xFF6C63FF)),
  tablet('📟', 'Tablet', Color(0xFF00C897)),
  tv('📺', 'Smart TV', Color(0xFFFF7043)),
  camera('📷', 'Camera', Color(0xFFFFAA2C)),
  audio('🎧', 'Audio', Color(0xFFFF5C7A)),
  smartwatch('⌚', 'Wearable', Color(0xFF00D0D0)),
  console('🎮', 'Gaming', Color(0xFF9C27B0)),
  other('🔌', 'Other', Color(0xFF8E8EA0));

  final String emoji, label;
  final Color color;
  const DeviceCategory(this.emoji, this.label, this.color);
}

class DeviceModel {
  String id, name, walletId, ownerId;
  DeviceCategory category;
  String? brand,
      modelNo,
      serialNo,
      purchaseDate,
      purchasePrice,
      warrantyExpiry,
      notes,
      imei;
  DeviceModel({
    required this.id,
    required this.name,
    required this.walletId,
    required this.ownerId,
    required this.category,
    this.brand,
    this.modelNo,
    this.serialNo,
    this.purchaseDate,
    this.purchasePrice,
    this.warrantyExpiry,
    this.notes,
    this.imei,
  });

  bool get isUnderWarranty {
    if (warrantyExpiry == null) return false;
    final parts = warrantyExpiry!.split('-');
    if (parts.length != 3) return false;
    try {
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      ).isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }
}

final List<DeviceModel> mockDevices = [
  DeviceModel(
    id: 'd1',
    name: 'iPhone 15 Pro',
    walletId: 'personal',
    ownerId: 'me',
    category: DeviceCategory.phone,
    brand: 'Apple',
    modelNo: 'A3101',
    serialNo: 'SN123ABC',
    purchaseDate: '2024-01-15',
    purchasePrice: '₹1,34,900',
    warrantyExpiry: '2026-01-15',
    imei: '123456789012345',
  ),
  DeviceModel(
    id: 'd2',
    name: 'MacBook Pro 14"',
    walletId: 'personal',
    ownerId: 'me',
    category: DeviceCategory.laptop,
    brand: 'Apple',
    modelNo: 'MR7J3HN/A',
    purchaseDate: '2023-08-10',
    purchasePrice: '₹1,99,900',
    warrantyExpiry: '2025-08-10',
  ),
  DeviceModel(
    id: 'd3',
    name: 'Samsung 55" QLED',
    walletId: 'personal',
    ownerId: 'dad',
    category: DeviceCategory.tv,
    brand: 'Samsung',
    modelNo: 'QA55Q70C',
    purchaseDate: '2023-03-01',
    purchasePrice: '₹89,000',
    warrantyExpiry: '2024-03-01',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// AROUND THE HOUSE
// ─────────────────────────────────────────────────────────────────────────────

enum ApplianceRoom {
  kitchen('🍳', 'Kitchen'),
  living('🛋️', 'Living Room'),
  bedroom('🛏️', 'Bedroom'),
  bathroom('🚿', 'Bathroom'),
  study('📚', 'Study'),
  outdoor('🌿', 'Outdoor'),
  utility('🔧', 'Utility');

  final String emoji, label;
  const ApplianceRoom(this.emoji, this.label);
}

class Appliance {
  String id, name, walletId;
  ApplianceRoom room;
  String? brand, modelNo, purchaseDate, warrantyExpiry, notes;
  double? purchasePrice;
  Appliance({
    required this.id,
    required this.name,
    required this.walletId,
    required this.room,
    this.brand,
    this.modelNo,
    this.purchaseDate,
    this.warrantyExpiry,
    this.notes,
    this.purchasePrice,
  });
}

final List<Appliance> mockAppliances = [
  Appliance(
    id: 'a1',
    name: 'LG French Door Refrigerator',
    walletId: 'personal',
    room: ApplianceRoom.kitchen,
    brand: 'LG',
    modelNo: 'GL-T322RPZY',
    purchaseDate: '2022-06-15',
    warrantyExpiry: '2027-06-15',
    purchasePrice: 42000,
  ),
  Appliance(
    id: 'a2',
    name: 'Bosch Washing Machine',
    walletId: 'personal',
    room: ApplianceRoom.utility,
    brand: 'Bosch',
    modelNo: 'WAJ24267IN',
    purchaseDate: '2022-06-15',
    warrantyExpiry: '2027-06-15',
    purchasePrice: 36000,
  ),
  Appliance(
    id: 'a3',
    name: 'Dyson Vacuum Cleaner',
    walletId: 'personal',
    room: ApplianceRoom.living,
    brand: 'Dyson',
    modelNo: 'V15 Detect',
    purchaseDate: '2023-11-11',
    warrantyExpiry: '2025-11-11',
    purchasePrice: 44900,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// DOCUMENT VAULT
// ─────────────────────────────────────────────────────────────────────────────

enum DocCategory {
  identity('🪪', 'Identity', Color(0xFF6C63FF)),
  property('🏠', 'Property', Color(0xFF00C897)),
  education('🎓', 'Education', Color(0xFF4A9EFF)),
  medical('🏥', 'Medical', Color(0xFFFF7043)),
  financial('💰', 'Financial', Color(0xFFFFAA2C)),
  vehicle('🚗', 'Vehicle', Color(0xFFFF5C7A)),
  insurance('🛡️', 'Insurance', Color(0xFF9C27B0)),
  legal('⚖️', 'Legal', Color(0xFF00D0D0)),
  other('📄', 'Other', Color(0xFF8E8EA0));

  final String emoji, label;
  final Color color;
  const DocCategory(this.emoji, this.label, this.color);
}

class VaultDocument {
  String id, title, walletId, memberId;
  DocCategory category;
  String? docNo,
      issuedBy,
      issuedDate,
      expiryDate,
      notes,
      filePath,
      thumbnailEmoji;
  List<String> tags;
  DateTime addedOn;
  VaultDocument({
    required this.id,
    required this.title,
    required this.walletId,
    required this.memberId,
    required this.category,
    this.docNo,
    this.issuedBy,
    this.issuedDate,
    this.expiryDate,
    this.notes,
    this.filePath,
    this.thumbnailEmoji,
    List<String>? tags,
    DateTime? addedOn,
  }) : tags = tags ?? [],
       addedOn = addedOn ?? DateTime.now();
}

final List<VaultDocument> mockDocuments = [
  VaultDocument(
    id: 'doc1',
    title: 'Aadhaar Card',
    walletId: 'personal',
    memberId: 'me',
    category: DocCategory.identity,
    docNo: 'XXXX-XXXX-1234',
    issuedBy: 'UIDAI',
    thumbnailEmoji: '🪪',
    tags: ['identity', 'kyc'],
  ),
  VaultDocument(
    id: 'doc2',
    title: 'PAN Card',
    walletId: 'personal',
    memberId: 'me',
    category: DocCategory.identity,
    docNo: 'ABCDE1234F',
    issuedBy: 'Income Tax Dept',
    thumbnailEmoji: '💳',
    tags: ['identity', 'tax'],
  ),
  VaultDocument(
    id: 'doc3',
    title: 'House Registration Deed',
    walletId: 'personal',
    memberId: 'dad',
    category: DocCategory.property,
    issuedDate: '2015-04-12',
    issuedBy: 'Sub-Registrar Office',
    thumbnailEmoji: '🏠',
    tags: ['property', 'legal'],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// MY FUNCTIONS (Events, Gifts, Gifted)
// ─────────────────────────────────────────────────────────────────────────────

enum FunctionType {
  wedding('💒', 'Wedding'),
  naming('👶', 'Naming Ceremony'),
  earPiercing('👂', 'Ear Piercing'),
  engagement('💍', 'Engagement'),
  houseWarming('🏠', 'Housewarming'),
  birthday('🎂', 'Birthday'),
  anniversary('💑', 'Anniversary'),
  graduation('🎓', 'Graduation'),
  puberty('🌸', 'Puberty Ceremony'),
  other('🎊', 'Others');

  final String emoji, label;
  const FunctionType(this.emoji, this.label);
}

enum GiftType {
  gold('🥇', 'Gold'),
  silver('🥈', 'Silver'),
  household('🏠', 'Household'),
  clothing('👗', 'Clothing'),
  giftItem('🎁', 'Gift Item'),
  giftCard('🎴', 'Gift Card'),
  other('✨', 'Others');

  final String emoji, label;
  const GiftType(this.emoji, this.label);
}

class GiftEntry {
  String id, guestName;
  String? guestPlace, phone, relation;
  GiftType giftType;
  double? cashAmount;
  double? goldGrams, silverGrams;
  String? itemDescription, giftCardValue, notes;
  GiftEntry({
    required this.id,
    required this.guestName,
    required this.giftType,
    this.guestPlace,
    this.phone,
    this.relation,
    this.cashAmount,
    this.goldGrams,
    this.silverGrams,
    this.itemDescription,
    this.giftCardValue,
    this.notes,
  });

  String get summary {
    switch (giftType) {
      case GiftType.gold:
        return goldGrams != null ? '${goldGrams}g Gold' : 'Gold';
      case GiftType.silver:
        return silverGrams != null ? '${silverGrams}g Silver' : 'Silver';
      case GiftType.giftCard:
        return giftCardValue != null ? '₹$giftCardValue Card' : 'Gift Card';
      default:
        return itemDescription ?? giftType.label;
    }
  }
}

enum VendorCategory {
  catering('🍽️', 'Catering'),
  venue('🏛️', 'Venue'),
  decoration('🎪', 'Decoration'),
  photography('📸', 'Photography & Videography'),
  entertainment('🎵', 'Entertainment'),
  clothing('👗', 'Clothing'),
  makeup('💄', 'Makeup'),
  jewelry('💍', 'Jewelry'),
  accessories('👜', 'Accessories'),
  ritualServices('🪔', 'Ritual Services'),
  accommodation('🏨', 'Accommodation'),
  invitations('✉️', 'Invitations'),
  returnGifts('🎁', 'Return Gifts'),
  supportServices('🤝', 'Support Services');

  final String emoji, label;
  const VendorCategory(this.emoji, this.label);
}

class FunctionVendor {
  String id, name;
  VendorCategory category;
  String? phone, email, address;
  double? totalCost, advancePaid;
  String? eventLinked;
  String? notes;

  FunctionVendor({
    required this.id,
    required this.name,
    required this.category,
    this.phone,
    this.email,
    this.address,
    this.totalCost,
    this.advancePaid,
    this.eventLinked,
    this.notes,
  });

  double get balance => (totalCost ?? 0) - (advancePaid ?? 0);
}

// ─────────────────────────────────────────────────────────────────────────────
// MOI (Indian traditional monetary gift / obligation system)
// ─────────────────────────────────────────────────────────────────────────────

// Whether this moi entry is a new moi (fresh gift) or a return moi
// (returning what we received from them previously)
enum MoiKind {
  newMoi('🆕', 'New Moi', Color(0xFF4A9EFF)),
  returnMoi('🔁', 'Return Moi', Color(0xFF00C897));

  final String emoji, label;
  final Color color;
  const MoiKind(this.emoji, this.label, this.color);
}

class MoiEntry {
  String id;
  String personName;
  String? familyName;
  String? place;
  String? phone;
  String? relation;
  double amount; // amount given to us at this function
  MoiKind kind; // new moi or return moi
  bool returned; // have we returned this moi yet?
  double? returnedAmount; // how much we returned (if returned)
  DateTime? returnedOn; // when we returned
  String? returnedForFunction; // which function we returned this moi at
  String? notes;

  MoiEntry({
    required this.id,
    required this.personName,
    required this.amount,
    required this.kind,
    this.familyName,
    this.place,
    this.phone,
    this.relation,
    this.returned = false,
    this.returnedAmount,
    this.returnedOn,
    this.returnedForFunction,
    this.notes,
  });

  factory MoiEntry.fromJson(Map<String, dynamic> j) => MoiEntry(
    id: j['id'] as String,
    personName: j['person_name'] as String,
    familyName: j['family_name'] as String?,
    place: j['place'] as String?,
    phone: j['phone'] as String?,
    relation: j['relation'] as String?,
    amount: (j['amount'] as num).toDouble(),
    kind: j['kind'] == 'returnMoi' ? MoiKind.returnMoi : MoiKind.newMoi,
    returned: j['returned'] as bool? ?? false,
    returnedAmount: j['returned_amount'] != null
        ? (j['returned_amount'] as num).toDouble()
        : null,
    returnedOn: j['returned_on'] != null
        ? DateTime.parse(j['returned_on'] as String)
        : null,
    returnedForFunction: j['returned_for_function'] as String?,
    notes: j['notes'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'person_name': personName,
    'family_name': familyName,
    'place': place,
    'phone': phone,
    'relation': relation,
    'amount': amount,
    'kind': kind.name,
    'returned': returned,
    'returned_amount': returnedAmount,
    'returned_on': returnedOn?.toIso8601String().split('T').first,
    'returned_for_function': returnedForFunction,
    'notes': notes,
  };
}

class FunctionChatMessage {
  String id, senderId, text;
  DateTime at;
  FunctionChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.at,
  });
}

class FunctionModel {
  String id, walletId;
  FunctionType type;
  String title, whoFunction;
  String? customType;
  DateTime? functionDate;
  String? venue, address, notes;
  bool isPlanned;
  String icon;
  List<GiftEntry> gifts;
  List<MoiEntry> moi;
  List<FunctionVendor> vendors;
  List<FunctionChatMessage> chat;
  List<String> memberIds;
  FunctionModel({
    required this.id,
    required this.walletId,
    required this.type,
    required this.title,
    this.whoFunction = '',
    this.customType,
    this.functionDate,
    this.venue,
    this.address,
    this.notes,
    this.isPlanned = false,
    this.icon = '🎊',
    List<GiftEntry>? gifts,
    List<MoiEntry>? moi,
    List<FunctionVendor>? vendors,
    List<FunctionChatMessage>? chat,
    List<String>? memberIds,
  }) : gifts = gifts ?? [],
       moi = moi ?? [],
       vendors = vendors ?? [],
       chat = chat ?? [],
       memberIds = memberIds ?? ['me'];

  double get totalCash => moi.fold(0.0, (s, m) => s + m.amount);
  double get totalGold => gifts
      .where((g) => g.giftType == GiftType.gold)
      .fold(0, (s, g) => s + (g.goldGrams ?? 0));
  double get totalSilver => gifts
      .where((g) => g.giftType == GiftType.silver)
      .fold(0, (s, g) => s + (g.silverGrams ?? 0));

  // Moi totals
  double get totalMoiReceived => moi.fold(0.0, (s, m) => s + m.amount);
  double get totalMoiReturned => moi
      .where((m) => m.returned)
      .fold(0.0, (s, m) => s + (m.returnedAmount ?? m.amount));
  int get moiPending => moi.where((m) => !m.returned).length;

  factory FunctionModel.fromJson(Map<String, dynamic> json) => FunctionModel(
    id: json['id'] as String,
    walletId: json['wallet_id'] as String,
    type: FunctionType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => FunctionType.other,
    ),
    title: json['title'] as String? ?? '',
    whoFunction: json['who_function'] as String? ?? '',
    customType: json['custom_type'] as String?,
    functionDate: json['function_date'] != null
        ? DateTime.parse(json['function_date'] as String)
        : null,
    venue: json['venue'] as String?,
    address: json['address'] as String?,
    notes: json['notes'] as String?,
    isPlanned: json['is_planned'] as bool? ?? false,
    icon: json['icon'] as String? ?? '🎊',
  );

  Map<String, dynamic> toJson() => {
    'wallet_id': walletId,
    'type': type.name,
    'title': title,
    'who_function': whoFunction,
    if (customType != null) 'custom_type': customType,
    if (functionDate != null) 'function_date': functionDate!.toIso8601String().split('T')[0],
    if (venue != null) 'venue': venue,
    if (address != null) 'address': address,
    if (notes != null) 'notes': notes,
    'is_planned': isPlanned,
    'icon': icon,
  };
}

class GiftedItem {
  String id, walletId, toName, functionTitle, memberId;
  FunctionType functionType;
  GiftType giftType;
  DateTime? functionDate;
  String? venue, notes, toPlace, toPhone, relation;
  double? cashAmount, goldGrams, silverGrams;
  String? itemDescription, giftCardValue;
  bool isReturnGift;
  GiftedItem({
    required this.id,
    required this.walletId,
    required this.toName,
    required this.functionTitle,
    required this.memberId,
    required this.functionType,
    required this.giftType,
    this.functionDate,
    this.venue,
    this.notes,
    this.toPlace,
    this.toPhone,
    this.relation,
    this.cashAmount,
    this.goldGrams,
    this.silverGrams,
    this.itemDescription,
    this.giftCardValue,
    this.isReturnGift = false,
  });

  String get giftSummary {
    switch (giftType) {
      case GiftType.gold:
        return goldGrams != null ? '${goldGrams}g Gold' : 'Gold';
      case GiftType.silver:
        return silverGrams != null ? '${silverGrams}g Silver' : 'Silver';
      default:
        return giftType.label;
    }
  }
}

class PlannedGiftItem {
  String category; // e.g. 'Cash', 'Gold'
  String? notes;
  PlannedGiftItem({required this.category, this.notes});

  factory PlannedGiftItem.fromJson(Map<String, dynamic> json) =>
      PlannedGiftItem(category: json['category'] ?? '', notes: json['notes'] as String?);

  Map<String, dynamic> toJson() => {'category': category, if (notes != null) 'notes': notes};
}

class UpcomingFunction {
  String id, walletId, personName, functionTitle, memberId;
  String? familyName;
  FunctionType type;
  DateTime? date;
  String? venue, notes;
  List<PlannedGiftItem> plannedGifts;
  List<FunctionChatMessage> chat;
  List<String> memberIds;
  Map<String, String> votes; // memberId → gift category label
  UpcomingFunction({
    required this.id,
    required this.walletId,
    required this.personName,
    required this.functionTitle,
    required this.memberId,
    required this.type,
    this.familyName,
    this.date,
    this.venue,
    this.notes,
    List<PlannedGiftItem>? plannedGifts,
    List<FunctionChatMessage>? chat,
    List<String>? memberIds,
    Map<String, String>? votes,
  }) : plannedGifts = plannedGifts ?? [],
       chat = chat ?? [],
       memberIds = memberIds ?? ['me'],
       votes = votes ?? {};

  factory UpcomingFunction.fromJson(Map<String, dynamic> json) => UpcomingFunction(
    id: json['id'] as String,
    walletId: json['wallet_id'] as String,
    personName: json['person_name'] as String? ?? '',
    familyName: json['family_name'] as String?,
    functionTitle: json['function_title'] as String? ?? '',
    memberId: 'me',
    type: FunctionType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => FunctionType.other,
    ),
    date: json['date'] != null ? DateTime.parse(json['date'] as String) : null,
    venue: json['venue'] as String?,
    notes: json['notes'] as String?,
    plannedGifts: (json['planned_gifts'] as List<dynamic>? ?? [])
        .map((g) => PlannedGiftItem.fromJson(g as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'wallet_id': walletId,
    'type': type.name,
    'person_name': personName,
    if (familyName != null) 'family_name': familyName,
    'function_title': functionTitle,
    if (date != null) 'date': date!.toIso8601String().split('T')[0],
    if (venue != null) 'venue': venue,
    if (notes != null) 'notes': notes,
    'planned_gifts': plannedGifts.map((g) => g.toJson()).toList(),
  };
}

class AttendedFunction {
  String id, walletId, functionName;
  String? personName, familyName;
  FunctionType type;
  DateTime? date;
  String? venue, notes;
  List<PlannedGiftItem> gifts; // what was given
  AttendedFunction({
    required this.id,
    required this.walletId,
    required this.functionName,
    required this.type,
    this.personName,
    this.familyName,
    this.date,
    this.venue,
    this.notes,
    List<PlannedGiftItem>? gifts,
  }) : gifts = gifts ?? [];

  factory AttendedFunction.fromJson(Map<String, dynamic> json) => AttendedFunction(
    id: json['id'] as String,
    walletId: json['wallet_id'] as String,
    functionName: json['function_name'] as String? ?? '',
    personName: json['person_name'] as String?,
    familyName: json['family_name'] as String?,
    type: FunctionType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => FunctionType.other,
    ),
    date: json['date'] != null ? DateTime.parse(json['date'] as String) : null,
    venue: json['venue'] as String?,
    notes: json['notes'] as String?,
    gifts: (json['gifts'] as List<dynamic>? ?? [])
        .map((g) => PlannedGiftItem.fromJson(g as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'wallet_id': walletId,
    'type': type.name,
    'function_name': functionName,
    if (personName != null) 'person_name': personName,
    if (familyName != null) 'family_name': familyName,
    if (date != null) 'date': date!.toIso8601String().split('T')[0],
    if (venue != null) 'venue': venue,
    if (notes != null) 'notes': notes,
    'gifts': gifts.map((g) => g.toJson()).toList(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// PLANNED FUNCTION — PARTICIPANTS
// ─────────────────────────────────────────────────────────────────────────────

class ParticipantFamilyMember {
  String name, relation;
  ParticipantFamilyMember({required this.name, required this.relation});

  factory ParticipantFamilyMember.fromJson(Map<String, dynamic> j) =>
      ParticipantFamilyMember(
        name: j['name'] as String? ?? '',
        relation: j['relation'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'name': name, 'relation': relation};
}

class FunctionParticipant {
  String id, functionId, name;
  String? place, relation, phone;
  List<ParticipantFamilyMember> familyMembers;

  FunctionParticipant({
    required this.id,
    required this.functionId,
    required this.name,
    this.place,
    this.relation,
    this.phone,
    List<ParticipantFamilyMember>? familyMembers,
  }) : familyMembers = familyMembers ?? [];

  factory FunctionParticipant.fromJson(Map<String, dynamic> j) =>
      FunctionParticipant(
        id: j['id'] as String,
        functionId: j['function_id'] as String,
        name: j['name'] as String,
        place: j['place'] as String?,
        relation: j['relation'] as String?,
        phone: j['phone'] as String?,
        familyMembers: (j['family_members'] as List<dynamic>? ?? [])
            .map((m) => ParticipantFamilyMember.fromJson(m as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'function_id': functionId,
    'name': name,
    if (place != null) 'place': place,
    if (relation != null) 'relation': relation,
    if (phone != null) 'phone': phone,
    'family_members': familyMembers.map((m) => m.toJson()).toList(),
  };

  int get totalCount => 1 + familyMembers.length;
}

// ─────────────────────────────────────────────────────────────────────────────
// PLANNED FUNCTION — CLOTHING GIFTS
// ─────────────────────────────────────────────────────────────────────────────

enum FunctionClothingGender {
  men('👨', 'Men'),
  women('👩', 'Women'),
  boy('👦', 'Boy'),
  girl('👧', 'Girl'),
  infant('👶', 'Infant');

  final String emoji, label;
  const FunctionClothingGender(this.emoji, this.label);
}

class ClothingMember {
  String name;
  FunctionClothingGender gender;
  String? dressType, size, brand;
  double? budget;
  bool purchased;

  ClothingMember({
    required this.name,
    required this.gender,
    this.dressType,
    this.size,
    this.brand,
    this.budget,
    this.purchased = false,
  });

  factory ClothingMember.fromJson(Map<String, dynamic> j) => ClothingMember(
    name: j['name'] as String? ?? '',
    gender: FunctionClothingGender.values.firstWhere(
      (e) => e.name == j['gender'],
      orElse: () => FunctionClothingGender.men,
    ),
    dressType: j['dress_type'] as String?,
    size: j['size'] as String?,
    brand: j['brand'] as String?,
    budget: (j['budget'] as num?)?.toDouble(),
    purchased: j['purchased'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'gender': gender.name,
    if (dressType != null) 'dress_type': dressType,
    if (size != null) 'size': size,
    if (brand != null) 'brand': brand,
    if (budget != null) 'budget': budget,
    'purchased': purchased,
  };
}

class ClothingFamily {
  String id, functionId, familyName;
  List<ClothingMember> members;

  ClothingFamily({
    required this.id,
    required this.functionId,
    required this.familyName,
    List<ClothingMember>? members,
  }) : members = members ?? [];

  factory ClothingFamily.fromJson(Map<String, dynamic> j) => ClothingFamily(
    id: j['id'] as String,
    functionId: j['function_id'] as String,
    familyName: j['family_name'] as String,
    members: (j['members'] as List<dynamic>? ?? [])
        .map((m) => ClothingMember.fromJson(m as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'function_id': functionId,
    'family_name': familyName,
    'members': members.map((m) => m.toJson()).toList(),
  };

  double get totalBudget =>
      members.fold(0, (s, m) => s + (m.budget ?? 0));
  int get purchasedCount => members.where((m) => m.purchased).length;
}

// ─────────────────────────────────────────────────────────────────────────────
// PLANNED FUNCTION — BRIDAL ESSENTIALS
// ─────────────────────────────────────────────────────────────────────────────

enum BridalStatus {
  pending('⏳', 'Pending'),
  booked('📋', 'Booked'),
  done('✅', 'Done');

  final String emoji, label;
  const BridalStatus(this.emoji, this.label);
}

class BridalEssential {
  String id, functionId, item;
  String? category, details, vendor;
  BridalStatus status;
  double? cost;

  BridalEssential({
    required this.id,
    required this.functionId,
    required this.item,
    this.category,
    this.details,
    this.vendor,
    this.status = BridalStatus.pending,
    this.cost,
  });

  factory BridalEssential.fromJson(Map<String, dynamic> j) => BridalEssential(
    id: j['id'] as String,
    functionId: j['function_id'] as String,
    item: j['item'] as String,
    category: j['category'] as String?,
    details: j['details'] as String?,
    vendor: j['vendor'] as String?,
    status: BridalStatus.values.firstWhere(
      (e) => e.name == j['status'],
      orElse: () => BridalStatus.pending,
    ),
    cost: (j['cost'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'function_id': functionId,
    'item': item,
    if (category != null) 'category': category,
    if (details != null) 'details': details,
    if (vendor != null) 'vendor': vendor,
    'status': status.name,
    if (cost != null) 'cost': cost,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// PLANNED FUNCTION — RETURN GIFTS
// ─────────────────────────────────────────────────────────────────────────────

class FunctionReturnGift {
  String id, functionId, giftName;
  double? approxPrice;
  String? whereToBuy, vendor;
  int quantity;

  FunctionReturnGift({
    required this.id,
    required this.functionId,
    required this.giftName,
    this.approxPrice,
    this.whereToBuy,
    this.vendor,
    this.quantity = 1,
  });

  factory FunctionReturnGift.fromJson(Map<String, dynamic> j) =>
      FunctionReturnGift(
        id: j['id'] as String,
        functionId: j['function_id'] as String,
        giftName: j['gift_name'] as String,
        approxPrice: (j['approx_price'] as num?)?.toDouble(),
        whereToBuy: j['where_to_buy'] as String?,
        vendor: j['vendor'] as String?,
        quantity: j['quantity'] as int? ?? 1,
      );

  Map<String, dynamic> toJson() => {
    'function_id': functionId,
    'gift_name': giftName,
    if (approxPrice != null) 'approx_price': approxPrice,
    if (whereToBuy != null) 'where_to_buy': whereToBuy,
    if (vendor != null) 'vendor': vendor,
    'quantity': quantity,
  };

  double get totalCost => (approxPrice ?? 0) * quantity;
}

// Mock data
final List<AttendedFunction> mockAttended = [];

final List<FunctionModel> mockFunctions = [
  FunctionModel(
    id: 'f1',
    walletId: 'personal',
    type: FunctionType.wedding,
    title: 'Arjun\'s Wedding',
    whoFunction: 'Son - Arjun',
    functionDate: DateTime(2025, 3, 12),
    venue: 'Grand Palace Hall',
    address: 'Anna Nagar, Chennai',
    gifts: [
      GiftEntry(
        id: 'g1',
        guestName: 'Ramesh Kumar',
        guestPlace: 'Coimbatore',
        giftType: GiftType.gold,
        goldGrams: 8,
        relation: 'Uncle',
      ),
      GiftEntry(
        id: 'g2',
        guestName: 'Lakshmi Devi',
        guestPlace: 'Madurai',
        giftType: GiftType.gold,
        goldGrams: 10,
        relation: 'Aunt',
      ),
      GiftEntry(
        id: 'g3',
        guestName: 'Vijay & Family',
        guestPlace: 'Chennai',
        giftType: GiftType.silver,
        silverGrams: 50,
      ),
    ],
    vendors: [
      FunctionVendor(
        id: 'v1',
        name: 'Sri Krishna Catering',
        category: VendorCategory.catering,
        phone: '9876543210',
        totalCost: 180000,
        advancePaid: 50000,
        notes: 'Full Vegetarian',
      ),
      FunctionVendor(
        id: 'v2',
        name: 'Grand Palace Hall',
        category: VendorCategory.venue,
        totalCost: 150000,
        advancePaid: 75000,
        notes: 'AC Hall 500 pax',
      ),
    ],
    memberIds: ['me', 'dad', 'mom'],
    moi: [
      MoiEntry(
        id: 'm1',
        personName: 'Selvam Chettiar',
        place: 'Coimbatore',
        amount: 5000,
        kind: MoiKind.newMoi,
        relation: 'Family Friend',
        phone: '9876543220',
      ),
      MoiEntry(
        id: 'm2',
        personName: 'Murugan & Family',
        place: 'Madurai',
        amount: 3000,
        kind: MoiKind.returnMoi,
        relation: 'Uncle',
        returned: true,
        returnedAmount: 3000,
        returnedOn: DateTime(2025, 4, 10),
      ),
      MoiEntry(
        id: 'm3',
        personName: 'Annamalai Pillai',
        place: 'Trichy',
        amount: 10000,
        kind: MoiKind.newMoi,
        relation: 'Close Friend',
      ),
      MoiEntry(
        id: 'm4',
        personName: 'Veerasamy',
        place: 'Chennai',
        amount: 2000,
        kind: MoiKind.returnMoi,
        relation: 'Colleague',
      ),
    ],
  ),
];

final List<GiftedItem> mockGifted = [
  GiftedItem(
    id: 'gi1',
    walletId: 'personal',
    toName: 'Suresh Bhai',
    memberId: 'me',
    functionTitle: 'House Warming',
    functionType: FunctionType.houseWarming,
    giftType: GiftType.gold,
    goldGrams: 4,
    functionDate: DateTime(2024, 8, 15),
    venue: 'Porur, Chennai',
    toPlace: 'Chennai',
    isReturnGift: false,
  ),
];

final List<UpcomingFunction> mockUpcoming = [
  UpcomingFunction(
    id: 'u1',
    walletId: 'personal',
    personName: 'Priya Anand',
    functionTitle: 'Wedding',
    memberId: 'me',
    type: FunctionType.wedding,
    date: DateTime(2025, 5, 20),
    venue: 'Kalyanam Matrimony Hall',
    plannedGifts: [
      PlannedGiftItem(category: 'Cash', notes: '₹5000'),
      PlannedGiftItem(category: 'Gold'),
    ],
    memberIds: ['me', 'dad', 'mom'],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// ITEM LOCATOR
// ─────────────────────────────────────────────────────────────────────────────

enum StorageType {
  shelf('📦', 'Shelf', Color(0xFF4A9EFF)),
  cupboard('🗄️', 'Cupboard', Color(0xFF9C27B0)),
  box('📫', 'Box', Color(0xFFFFAA2C)),
  almirah('🪞', 'Almirah', Color(0xFF00C897)),
  drawer('🗂️', 'Drawer', Color(0xFFFF7043)),
  bag('🎒', 'Bag', Color(0xFFFF5CA8)),
  fridge('❄️', 'Fridge', Color(0xFF00D0D0)),
  attic('🏚️', 'Attic', Color(0xFF8D6E63)),
  locker('🔒', 'Locker', Color(0xFFFF5C7A)),
  other('📍', 'Other', Color(0xFF8E8EA0));

  final String emoji, label;
  final Color color;
  const StorageType(this.emoji, this.label, this.color);
}

// A named container instance — e.g. "Box 1", "Bedroom Cupboard"
class StorageContainer {
  String id;
  String walletId;
  StorageType type;
  String name; // e.g. "Box 1", "Kitchen Shelf", "Bedroom Almirah"
  String? location; // room or area — e.g. "Bedroom", "Store Room"
  String? notes;
  String? color; // optional colour label — "Blue box", "Red bag"
  DateTime createdAt;

  StorageContainer({
    required this.id,
    required this.walletId,
    required this.type,
    required this.name,
    this.location,
    this.notes,
    this.color,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

// An item stored inside a container
class StoredItem {
  String id;
  String walletId;
  String containerId;
  String name;
  String? description;
  String? category; // e.g. "Documents", "Clothes", "Electronics"
  String? emoji;
  DateTime storedOn;
  String? storedBy; // member id
  String? notes;
  bool isFragile;
  bool isImportant;

  StoredItem({
    required this.id,
    required this.walletId,
    required this.containerId,
    required this.name,
    this.description,
    this.category,
    this.emoji,
    DateTime? storedOn,
    this.storedBy,
    this.notes,
    this.isFragile = false,
    this.isImportant = false,
  }) : storedOn = storedOn ?? DateTime.now();
}

// Mock data
final List<StorageContainer> mockContainers = [
  StorageContainer(
    id: 'sc1',
    walletId: 'personal',
    type: StorageType.almirah,
    name: 'Bedroom Almirah',
    location: 'Bedroom',
    notes: 'Left side — my clothes, right side — formal wear',
  ),
  StorageContainer(
    id: 'sc2',
    walletId: 'personal',
    type: StorageType.box,
    name: 'Box 1',
    location: 'Store Room',
    color: 'Brown',
    notes: 'Old documents and certificates',
  ),
  StorageContainer(
    id: 'sc3',
    walletId: 'personal',
    type: StorageType.box,
    name: 'Box 2',
    location: 'Store Room',
    color: 'Blue',
    notes: 'Kitchen extras and festival items',
  ),
  StorageContainer(
    id: 'sc4',
    walletId: 'personal',
    type: StorageType.shelf,
    name: 'Study Shelf',
    location: 'Study Room',
  ),
  StorageContainer(
    id: 'sc5',
    walletId: 'personal',
    type: StorageType.drawer,
    name: 'Bedside Drawer',
    location: 'Bedroom',
  ),
  StorageContainer(
    id: 'sc6',
    walletId: 'personal',
    type: StorageType.cupboard,
    name: 'Kitchen Cupboard',
    location: 'Kitchen',
  ),
];

final List<StoredItem> mockStoredItems = [
  // Bedroom Almirah
  StoredItem(
    id: 'si1',
    walletId: 'personal',
    containerId: 'sc1',
    name: 'Passport',
    emoji: '📘',
    category: 'Documents',
    storedBy: 'me',
    isImportant: true,
    notes: 'In the small zippered pocket on the right side',
  ),
  StoredItem(
    id: 'si2',
    walletId: 'personal',
    containerId: 'sc1',
    name: 'Wedding Sherwani',
    emoji: '👘',
    category: 'Clothes',
    storedBy: 'me',
    notes: 'Wrapped in plastic cover',
  ),
  StoredItem(
    id: 'si3',
    walletId: 'personal',
    containerId: 'sc1',
    name: 'Gold Chain',
    emoji: '📿',
    category: 'Jewellery',
    storedBy: 'mom',
    isImportant: true,
    isFragile: true,
    notes: 'In the small velvet box',
  ),

  // Box 1
  StoredItem(
    id: 'si4',
    walletId: 'personal',
    containerId: 'sc2',
    name: 'School Certificates',
    emoji: '📜',
    category: 'Documents',
    storedBy: 'me',
    isImportant: true,
  ),
  StoredItem(
    id: 'si5',
    walletId: 'personal',
    containerId: 'sc2',
    name: 'Old Photographs',
    emoji: '🖼️',
    category: 'Memories',
    storedBy: 'mom',
  ),

  // Box 2
  StoredItem(
    id: 'si6',
    walletId: 'personal',
    containerId: 'sc3',
    name: 'Diwali Diyas',
    emoji: '🪔',
    category: 'Festival',
    storedBy: 'mom',
    notes: 'Handle with care — clay diyas',
  ),
  StoredItem(
    id: 'si7',
    walletId: 'personal',
    containerId: 'sc3',
    name: 'Mixer Grinder Jar (Extra)',
    emoji: '🫙',
    category: 'Kitchen',
    storedBy: 'mom',
  ),

  // Study Shelf
  StoredItem(
    id: 'si8',
    walletId: 'personal',
    containerId: 'sc4',
    name: 'Router & Cables',
    emoji: '📡',
    category: 'Electronics',
    storedBy: 'me',
  ),
  StoredItem(
    id: 'si9',
    walletId: 'personal',
    containerId: 'sc4',
    name: 'Tax Documents FY23',
    emoji: '📂',
    category: 'Documents',
    storedBy: 'dad',
    isImportant: true,
  ),

  // Bedside Drawer
  StoredItem(
    id: 'si10',
    walletId: 'personal',
    containerId: 'sc5',
    name: 'Car Keys (Spare)',
    emoji: '🔑',
    category: 'Keys',
    storedBy: 'me',
    isImportant: true,
  ),
  StoredItem(
    id: 'si11',
    walletId: 'personal',
    containerId: 'sc5',
    name: 'Medicine (Paracetamol)',
    emoji: '💊',
    category: 'Medicine',
    storedBy: 'mom',
  ),

  // Kitchen Cupboard
  StoredItem(
    id: 'si12',
    walletId: 'personal',
    containerId: 'sc6',
    name: 'Ration Bag (Wheat)',
    emoji: '🌾',
    category: 'Grocery',
    storedBy: 'mom',
    notes: '10kg bag, half remaining',
  ),
];
