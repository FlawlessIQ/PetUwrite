/// Model class representing the pet owner
class Owner {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final Address address;
  final DateTime? dateOfBirth;
  
  Owner({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.address,
    this.dateOfBirth,
  });
  
  String get fullName => '$firstName $lastName';
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'address': address.toJson(),
      'dateOfBirth': dateOfBirth?.toIso8601String(),
    };
  }
  
  factory Owner.fromJson(Map<String, dynamic> json) {
    return Owner(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String,
      address: Address.fromJson(json['address'] as Map<String, dynamic>),
      dateOfBirth: json['dateOfBirth'] != null 
          ? DateTime.parse(json['dateOfBirth'] as String)
          : null,
    );
  }
  
  Owner copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    Address? address,
    DateTime? dateOfBirth,
  }) {
    return Owner(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    );
  }
}

/// Model class for address information
class Address {
  final String street;
  final String city;
  final String state;
  final String zipCode;
  final String country;
  
  Address({
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.country,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'street': street,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'country': country,
    };
  }
  
  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      street: json['street'] as String,
      city: json['city'] as String,
      state: json['state'] as String,
      zipCode: json['zipCode'] as String,
      country: json['country'] as String,
    );
  }
  
  @override
  String toString() => '$street, $city, $state $zipCode, $country';
}
