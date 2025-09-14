class Company {
  final String id;
  final String name;
  final String? primaryContact;
  final String? secondaryContact;
  final List<String> missionOrdersIds;
  final String? hubspotId;

  Company({
    required this.id,
    required this.name,
    this.primaryContact,
    this.secondaryContact,
    this.hubspotId,
    this.missionOrdersIds = const [],
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    String? hubspotId;
    if (json.containsKey('hubspot_company_id')) {
      hubspotId = json['hubspot_company_id'];
    }

    // Handle primary_contact - it can be either a string ID or an object
    String? primaryContact;
    if (json['primary_contact'] != null) {
      if (json['primary_contact'] is String) {
        primaryContact = json['primary_contact'];
      } else if (json['primary_contact'] is Map) {
        primaryContact = json['primary_contact']['id'];
      }
    }

    // Handle secondary_contact - it can be either a string ID or an object
    String? secondaryContact;
    if (json['secondary_contact'] != null) {
      if (json['secondary_contact'] is String) {
        secondaryContact = json['secondary_contact'];
      } else if (json['secondary_contact'] is Map) {
        secondaryContact = json['secondary_contact']['id'];
      }
    }

    return Company(
      id: json['id'],
      name: json['name'],
      primaryContact: primaryContact,
      secondaryContact: secondaryContact,
      hubspotId: hubspotId,
      missionOrdersIds: json['mission_order_ids'] != null ? List<String>.from(json['mission_order_ids']) : [],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'name': name,
      'primary_contact': primaryContact,
      'secondary_contact': secondaryContact,
      'hubspot_company_id': hubspotId,
      'mission_order_ids': missionOrdersIds,
    };

    return data;
  }
}
