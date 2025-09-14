import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import '../models/contact.dart';
import '../models/company.dart';
import '../models/mission_order.dart';

// class ApiService {
//   static const String baseUrl = 'http://localhost:3000';
//
//   // Future<List<Contact>> fetchContacts() async {
//   //   try {
//   //     final response = await http.get(Uri.parse('$baseUrl/contacts'));
//   //     if (response.statusCode == 200) {
//   //       final Map<String, dynamic> decoded = json.decode(response.body); // decode as Map, not List
//   //       final List<dynamic> data = decoded['data']; // extract the 'data' array
//   //       return data.map((json) => Contact.fromJson(json)).toList();
//   //     } else {
//   //       throw Exception('Failed to load contacts: ${response.statusCode}');
//   //     }
//   //   } catch (e) {
//   //     throw Exception('Error fetching contacts: $e');
//   //   }
//   // }
//
//   // Future<void> patchContact(Contact contact) async {
//   //   try {
//   //     final response = await http.patch(
//   //       Uri.parse('$baseUrl/contacts/${contact.id}'),
//   //       headers: {'Content-Type': 'application/json'},
//   //       body: json.encode(contact.toJson()),
//   //     );
//   //
//   //     if (response.statusCode != 200) {
//   //       throw Exception('Failed to update contact: ${response.statusCode}');
//   //     }
//   //   } catch (e) {
//   //     throw Exception('Error updating contact: $e');
//   //   }
//   // }
//
//   // Future<List<Company>> fetchCompanies() async {
//   //   try {
//   //     final response = await http.get(Uri.parse('$baseUrl/companies'));
//   //     if (response.statusCode == 200) {
//   //       final Map<String, dynamic> decoded = json.decode(response.body); // decode as Map, not List
//   //       final List<dynamic> data = decoded['data']; // extract the 'data' array
//   //       return data.map((json) => Company.fromJson(json)).toList();
//   //     } else {
//   //       throw Exception('Failed to load companies: ${response.statusCode}');
//   //     }
//   //   } catch (e) {
//   //     throw Exception('Error fetching companies: $e');
//   //   }
//   // }
//
//   // Future<List<MissionOrder>> fetchMissionOrders() async {
//   //   try {
//   //     final response = await http.get(Uri.parse('$baseUrl/mission-orders'));
//   //     if (response.statusCode == 200) {
//   //       final Map<String, dynamic> decoded = json.decode(response.body); // decode as Map, not List
//   //       final List<dynamic> data = decoded['data']; // extract the 'data' array
//   //       return data.map((json) => MissionOrder.fromJson(json)).toList();
//   //     } else {
//   //       throw Exception('Failed to load mission orders: ${response.statusCode}');
//   //     }
//   //   } catch (e) {
//   //     throw Exception('Error fetching mission orders: $e');
//   //   }
//   // }
//
//   // Future<List<MissionOrder>> fetchMissionOrdersByIds(List<String> ids) async {
//   //   if (ids.isEmpty) return [];
//   //
//   //   try {
//   //     final response = await http.get(Uri.parse('$baseUrl/mission-orders'));
//   //     if (response.statusCode == 200) {
//   //       final Map<String, dynamic> decoded = json.decode(response.body);
//   //       final List<dynamic> data = decoded['data'];
//   //       final allOrders = data.map((json) => MissionOrder.fromJson(json)).toList();
//   //
//   //       return allOrders.where((order) => ids.contains(order.id)).toList();
//   //     } else {
//   //       throw Exception('Failed to load mission orders: ${response.statusCode}');
//   //     }
//   //   } catch (e) {
//   //     throw Exception('Error fetching mission orders by IDs: $e');
//   //   }
//   // }
//
//   // Future<void> patchMissionOrder(MissionOrder missionOrder) async {
//   //   try {
//   //     final response = await http.patch(
//   //       Uri.parse('$baseUrl/mission-orders/${missionOrder.id}'),
//   //       headers: {'Content-Type': 'application/json'},
//   //       body: json.encode({'status': missionOrder.status.toString().split('.').last, 'notes': missionOrder.notes}),
//   //     );
//   //
//   //     if (response.statusCode != 200) {
//   //       throw Exception('Failed to update mission order: ${response.statusCode}');
//   //     }
//   //   } catch (e) {
//   //     throw Exception('Error updating mission order: $e');
//   //   }
//   // }
//
//   // Future<Map<String, dynamic>> createMissionOrder(MissionOrder missionOrder) async {
//   //   try {
//   //     final response = await http.post(
//   //       Uri.parse('$baseUrl/mission-orders'),
//   //       headers: {'Content-Type': 'application/json'},
//   //       body: json.encode(missionOrder.toJson()),
//   //     );
//   //
//   //     if (response.statusCode == 201) {
//   //       return json.decode(response.body);
//   //     } else {
//   //       throw Exception('Failed to create mission order: ${response.statusCode}');
//   //     }
//   //   } catch (e) {
//   //     throw Exception('Error creating mission order: $e');
//   //   }
//   // }
// }

class FunctionWrapper {
  FirebaseFunctions get instance => FirebaseFunctions.instance;

  Future<String> createDealOnHubSpot(MissionOrder order) async {
    final HttpsCallable callable = instance.httpsCallable('create_deal');
    final response = await callable.call(order.hubspotJSON());
    if (response.data != null && response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      if (data.containsKey('id') && data.containsKey('createdAt')) {
        return data['id'] as String;
      } else {
        throw Exception('dealId not found in response');
      }
    } else {
      throw Exception('Invalid response from Cloud Function');
    }
  }

  Future<void> updateDealOnHubSpot(MissionOrder order) async {

    final HttpsCallable callable = instance.httpsCallable('update_deal');
    Map<String, dynamic> payload = order.hubspotJSON();
    payload['hubspot_deal_id'] = order.hubspotId;
    await callable.call(payload);
  }
}

class FirestoreWrapper {
  // Placeholder for Firestore wrapper methods
  // Implement Firestore interactions here if needed
  FirebaseFirestore get instance => FirebaseFirestore.instance;
  final FunctionWrapper hubSpotWrapper = FunctionWrapper();

  //  === Mission Orders CRUD ===
  Future<String> createMissionOrder(MissionOrder missionOrder) async {
    String hubspotId = await hubSpotWrapper.createDealOnHubSpot(missionOrder);
    MissionOrder orderUpdated = missionOrder.copyWith(hubspotId: hubspotId);
    DocumentReference docRef = await instance.collection('mission_orders').add(orderUpdated.toJson());
    return docRef.id;
  }

  Future<void> updateMissionOrder(MissionOrder missionOrder) async {
    await instance.collection('mission_orders').doc(missionOrder.id).update(missionOrder.toJson());
  }

  Future<void> deleteMissionOrder(String id) async {
    await instance.collection('mission_orders').doc(id).delete();
  }

  Future<MissionOrder> getMissionOrderById(String id) async {
    DocumentSnapshot docSnap = await instance.collection('mission_orders').doc(id).get();
    if (docSnap.exists) {
      return MissionOrder.fromJson(docSnap.data() as Map<String, dynamic>);
    } else {
      throw Exception('MissionOrder with id $id not found');
    }
  }

  Future<List<MissionOrder>> getAllMissionOrders() async {
    List<MissionOrder> orders = [];
    QuerySnapshot querySnap = await instance.collection('mission_orders').get();
    for (var doc in querySnap.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id; // Ensure the id field is included

      if (data['contact_ids'] != null) {
        List<Contact> contacts = [];
        for (String contactId in List<String>.from(data['contact_ids'])) {
          Contact contact = await getContactById(contactId);
          contacts.add(contact);
        }

        data['contacts'] = contacts;
      } else {
        data['contacts'] = List<Contact>.from([]);
      }

      if (data['company_ids'] != null) {
        List<Company> companies = [];
        for (String companyId in List<String>.from(data['company_ids'])) {
          Company company = await getCompanyById(companyId);
          companies.add(company);
        }
        data['companies'] = companies;
      } else {
        data['companies'] = List<Company>.from([]);
      }

      orders.add(MissionOrder.fromJson(data));
    }

    return orders;
  }

  //  === Contacts CRUD ===

  Future<String> createContact(Contact contact) async {
    DocumentReference docRef = await instance.collection('contacts').add(contact.toJson());
    return docRef.id;
  }

  Future<void> updateContact(Contact contact) async {
    await instance.collection('contacts').doc(contact.id).update(contact.toJson());
  }

  Future<void> deleteContact(String id) async {
    await instance.collection('contacts').doc(id).delete();
  }

  Future<Contact> getContactById(String id) async {
    DocumentSnapshot docSnap = await instance.collection('contacts').doc(id).get();
    if (docSnap.exists) {
      Map<String, dynamic> data = docSnap.data() as Map<String, dynamic>;
      data['id'] = docSnap.id; // Ensure the id field is included
      return Contact.fromJson(data);
    } else {
      throw Exception('Contact with id $id not found');
    }
  }

  Future<List<Contact>> getAllContacts() async {
    List<Contact> contacts = [];
    QuerySnapshot querySnap = await instance.collection('contacts').get();
    for (var doc in querySnap.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id; // Ensure the id field is included
      contacts.add(Contact.fromJson(data));
    }

    return contacts;
  }

  // === Companies CRUD ===

  Future<String> createCompany(Company company) async {
    DocumentReference dofRef = await instance.collection('companies').add(company.toJson());
    return dofRef.id;
  }

  Future<void> updateCompany(Company company) async {
    await instance.collection('companies').doc(company.id).update(company.toJson());
  }

  Future<void> deleteCompany(String id) async {
    await instance.collection('companies').doc(id).delete();
  }

  Future<Company> getCompanyById(String id) async {
    DocumentSnapshot docSnap = await instance.collection('companies').doc(id).get();
    if (docSnap.exists) {
      Map<String, dynamic> data = docSnap.data() as Map<String, dynamic>;
      data['id'] = docSnap.id; // Ensure the id field is included
      return Company.fromJson(data);
    } else {
      throw Exception('Company with id $id not found');
    }
  }

  Future<List<Company>> getAllCompanies() async {
    List<Company> companies = [];
    QuerySnapshot querySnap = await instance.collection('companies').get();
    for (var doc in querySnap.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id; // Ensure the id field is included
      companies.add(Company.fromJson(data));
    }

    return companies;
  }
}

//
// import 'dart:convert';
// import 'package:http/http.dart' as http;
//
// class HubSpotService {
//   final String accessToken = "YOUR_PRIVATE_APP_TOKEN"; // e.g. pat-xxx
//
//   Future<Map<String, dynamic>> createDeal({
//     required String dealName,
//     required String pipeline,
//     required String stage,
//     double? amount,
//   }) async {
//     final url = Uri.parse("https://api.hubapi.com/crm/v3/objects/deals");
//
//     final headers = {
//       "Authorization": "Bearer $accessToken",
//       "Content-Type": "application/json",
//     };
//
//     final body = {
//       "properties": {
//         "dealname": dealName,
//         "pipeline": pipeline,     // e.g. "default"
//         "dealstage": stage,       // e.g. "appointmentscheduled"
//         if (amount != null) "amount": amount.toString(),
//       }
//     };
//
//     final response = await http.post(
//       url,
//       headers: headers,
//       body: jsonEncode(body),
//     );
//
//     if (response.statusCode == 201) {
//       return jsonDecode(response.body);
//     } else {
//       throw Exception(
//         "Failed to create deal: ${response.statusCode} - ${response.body}",
//       );
//     }
//   }
// }
