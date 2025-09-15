

import '../services/utils.dart';
import 'company.dart';
import 'contact.dart';

enum MissionOrderType { permanent, contract, freelance }

enum SalesPipelineStage {
  appointmentScheduled("appointmentscheduled"),
  qualifiedToBuy("qualifiedtobuy"),
  presentationScheduled("presentationscheduled"),
  decisionMakerBoughtIn("decisionmakerboughtin"),
  contractSent("contractsent"),
  closedWon("closedwon"),
  closedLost("closedlost");

  final String id;

  const SalesPipelineStage(this.id);
}

Map<String, SalesPipelineStage> salesPipelineStageValues = {
  'appointmentscheduled': SalesPipelineStage.appointmentScheduled,
  'qualifiedtobuy': SalesPipelineStage.qualifiedToBuy,
  'presentationscheduled': SalesPipelineStage.presentationScheduled,
  'decisionmakerboughtin': SalesPipelineStage.decisionMakerBoughtIn,
  'contractsent': SalesPipelineStage.contractSent,
  'closedwon': SalesPipelineStage.closedWon,
  'closedlost': SalesPipelineStage.closedLost,
};

Map<SalesPipelineStage, String> salesPipelineStageLabels = {
  SalesPipelineStage.appointmentScheduled: 'Appointment Scheduled',
  SalesPipelineStage.qualifiedToBuy: 'Qualified to Buy',
  SalesPipelineStage.presentationScheduled: 'Presentation Scheduled',
  SalesPipelineStage.decisionMakerBoughtIn: 'Decision Maker Bought In',
  SalesPipelineStage.contractSent: 'Contract Sent',
  SalesPipelineStage.closedWon: 'Closed Won',
  SalesPipelineStage.closedLost: 'Closed lost',
};

Map<String, MissionOrderType> missionOrderTypeValues = {
  'CDI': MissionOrderType.permanent,
  'Intérim': MissionOrderType.contract,
  'freelance': MissionOrderType.freelance,
};

Map<MissionOrderType, String> missionOrderTypeNames = {
  MissionOrderType.permanent: 'CDI',
  MissionOrderType.contract: 'Intérim',
  MissionOrderType.freelance: 'freelance',
};

enum MissionOrderStatus { draft, published, interview, hired, closed }

class MissionOrder {
  final String id;
  final String name;
  final MissionOrderType type;
  final String jobTitle;
  final String location;
  final DateTime startDate;
  final DateTime endDate;
  final MissionOrderStatus status;
  final SalesPipelineStage stage;
  final String amount;
  final String notes;
  final List<Contact> contacts;
  final List<Company> companies;
  final String? hubspotId;

  MissionOrder({
    required this.id,
    required this.name,
    required this.type,
    required this.jobTitle,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.stage,
    required this.amount,
    required this.notes,
    required this.contacts,
    required this.companies,
    this.hubspotId,
  });

  factory MissionOrder.fromJson(Map<String, dynamic> json) {
    DateTime startDate = DateTools.tryToParseDate(json['start_date']) ;
    DateTime endDate = DateTools.tryToParseDate(json['end_date']) ;
    MissionOrderType missionType = missionOrderTypeValues[json['type']] ?? MissionOrderType.contract;
    MissionOrderStatus status = MissionOrderStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => MissionOrderStatus.draft,
    );
    SalesPipelineStage stage = SalesPipelineStage.values.firstWhere(
      (e) => e.id == json['deal_stage'],
      orElse: () => SalesPipelineStage.appointmentScheduled,
    );

    MissionOrder m = MissionOrder(
      id: json['id'],
      name: json['name'] ?? 'no name set',
      type: missionType,
      jobTitle: json['job_title'] ?? '',
      location: json['location'] ?? '',
      startDate: startDate,
      endDate: endDate,
      status: status,
      stage: stage,
      amount: json['amount'] ?? '0',
      notes: json['notes'] ?? '',
      contacts: json['contacts'],
      companies: json['companies'],
      hubspotId: json['hubspot_deal_id'],
    );

    return m;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'notes': notes,
      'name': name,
      'type': type.name,
      'id': id,
      'job_title': jobTitle,
      'location': location,
      'start_date': startDate,
      'end_date': endDate,
      'amount': amount,
      'deal_stage': stage.id,

      'status': status.name,

      'contact_ids': contacts.map((c) => c.id).toList(),
      'company_ids': companies.map((c) => c.id).toList(),

      'hubspot_deal_id': hubspotId,
    };

    return data;
  }

  Map<String, dynamic> hubspotJSON() {
    final Map<String, dynamic> data = {
      'notes_internal': notes,
      'dealname': name,
      'contract_type': missionOrderTypeNames[type],
      'job_title': jobTitle,
      'location': location,
      'start_date': startDate.millisecondsSinceEpoch,
      'closedate': endDate.millisecondsSinceEpoch,
      'dealstage': stage.id,
      'amount': amount,
      // 'status': status.name,
      // 'contact_ids': contacts.map((c) => c.id).toList(),
      // 'company_ids': companies.map((c) => c.id).toList(),
    };

    return data;
  }

  MissionOrder copyWith({
    String? id,
    String? name,
    MissionOrderType? type,
    String? jobTitle,
    String? location,
    DateTime? startDate,
    DateTime? endDate,
    String? appointments,
    MissionOrderStatus? status,
    String? amount,
    SalesPipelineStage? stage,
    String? notes,
    List<Contact>? contacts,
    List<Company>? companies,
    String? hubspotId,
  }) {
    return MissionOrder(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      jobTitle: jobTitle ?? this.jobTitle,
      location: location ?? this.location,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
      stage: stage ?? this.stage,
      contacts: contacts ?? this.contacts,
      companies: companies ?? this.companies,
      hubspotId: hubspotId ?? this.hubspotId,
    );
  }
}
