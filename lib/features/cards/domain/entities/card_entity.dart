import 'package:my_card_wallet/core/utils/card_utils.dart';

enum CardTag { personal, business, travel, shopping, other }

class CardEntity {
  final String id;
  final String holderName;
  final String encryptedNumber;
  final String encryptedCVV;
  final String expiryMonth; // "01"–"12"
  final String expiryYear;  // "26", "27", etc.
  final String lastFour;
  final CardNetwork network;
  final CardTag tag;
  final String? bankName;
  final String? notes;
  final String? customColorHex;
  final DateTime addedAt;
  final DateTime? lastAccessedAt;

  const CardEntity({
    required this.id,
    required this.holderName,
    required this.encryptedNumber,
    required this.encryptedCVV,
    required this.expiryMonth,
    required this.expiryYear,
    required this.lastFour,
    required this.network,
    required this.tag,
    this.bankName,
    this.notes,
    this.customColorHex,
    required this.addedAt,
    this.lastAccessedAt,
  });

  String get maskedNumber => '•••• •••• •••• $lastFour';
  String get expiryDisplay => '$expiryMonth/$expiryYear';
  String get networkLabel => CardUtils.networkLabel(network);

  CardEntity copyWith({
    String? holderName,
    String? encryptedNumber,
    String? encryptedCVV,
    String? expiryMonth,
    String? expiryYear,
    String? lastFour,
    CardNetwork? network,
    CardTag? tag,
    String? bankName,
    String? notes,
    String? customColorHex,
    DateTime? lastAccessedAt,
  }) {
    return CardEntity(
      id: id,
      holderName: holderName ?? this.holderName,
      encryptedNumber: encryptedNumber ?? this.encryptedNumber,
      encryptedCVV: encryptedCVV ?? this.encryptedCVV,
      expiryMonth: expiryMonth ?? this.expiryMonth,
      expiryYear: expiryYear ?? this.expiryYear,
      lastFour: lastFour ?? this.lastFour,
      network: network ?? this.network,
      tag: tag ?? this.tag,
      bankName: bankName ?? this.bankName,
      notes: notes ?? this.notes,
      customColorHex: customColorHex ?? this.customColorHex,
      addedAt: addedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'holderName': holderName,
        'encryptedNumber': encryptedNumber,
        'encryptedCVV': encryptedCVV,
        'expiryMonth': expiryMonth,
        'expiryYear': expiryYear,
        'lastFour': lastFour,
        'network': network.name,
        'tag': tag.name,
        'bankName': bankName,
        'notes': notes,
        'customColorHex': customColorHex,
        'addedAt': addedAt.toIso8601String(),
        'lastAccessedAt': lastAccessedAt?.toIso8601String(),
      };

  factory CardEntity.fromJson(Map<String, dynamic> json) => CardEntity(
        id: json['id'] as String,
        holderName: json['holderName'] as String,
        encryptedNumber: json['encryptedNumber'] as String,
        encryptedCVV: json['encryptedCVV'] as String,
        expiryMonth: json['expiryMonth'] as String,
        expiryYear: json['expiryYear'] as String,
        lastFour: (json['lastFour'] as String?) ?? '????',
        network: CardNetwork.values.byName(
            (json['network'] as String?) ?? CardNetwork.unknown.name),
        tag: CardTag.values.byName(
            (json['tag'] as String?) ?? CardTag.personal.name),
        bankName: json['bankName'] as String?,
        notes: json['notes'] as String?,
        customColorHex: json['customColorHex'] as String?,
        addedAt: DateTime.parse(json['addedAt'] as String),
        lastAccessedAt: json['lastAccessedAt'] != null
            ? DateTime.parse(json['lastAccessedAt'] as String)
            : null,
      );
}
