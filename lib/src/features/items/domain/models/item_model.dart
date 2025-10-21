class Item {
  final String id;
  final String name;
  final String? description;
  final DateTime borrowedAt;
  final DateTime? returnedAt;
  final String borrowerName;
  final String? borrowerContact;
  final String? photoUrl;
  final String userId;

  Item({
    required this.id,
    required this.name,
    this.description,
    required this.borrowedAt,
    this.returnedAt,
    required this.borrowerName,
    this.borrowerContact,
    this.photoUrl,
    required this.userId,
  });

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      borrowedAt: DateTime.parse(map['borrowed_at']),
      returnedAt: map['returned_at'] != null
          ? DateTime.parse(map['returned_at'])
          : null,
      borrowerName: map['borrower_name'],
      borrowerContact: map['borrower_contact'],
      photoUrl: map['photo_url'],
      userId: map['user_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'borrowed_at': borrowedAt.toIso8601String(),
      'returned_at': returnedAt?.toIso8601String(),
      'borrower_name': borrowerName,
      'borrower_contact': borrowerContact,
      'photo_url': photoUrl,
      'user_id': userId,
    };
  }
}
