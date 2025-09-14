enum ContactType { internal, external }

class Contact {
  final String id;
  final String? hubspotId;
  final String firstName;
  final String lastName;
  final String email;
  final ContactType type;
  final List<String> missionOrdersIds;

  Contact({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.type,
    this.hubspotId,
    this.missionOrdersIds = const [],
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    String? hubspotId;
    if (json.containsKey('hubspot_contact_id')) {
      hubspotId = json['hubspot_contact_id'];
    }

    return Contact(
      id: json['id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
      hubspotId: hubspotId,
      type: ContactType.values.firstWhere((e) => e == json['type'], orElse: () => ContactType.external),
      missionOrdersIds: json['mission_order_ids'] != null ? List<String>.from(json['mission_order_ids']) : [],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'type': type.name,
      'hubspot_contact_id': hubspotId,
      'mission_order_ids': missionOrdersIds,
    };

    return data;
  }

  String get fullName => '$firstName $lastName';
}
