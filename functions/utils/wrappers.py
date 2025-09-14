import json
import logging
import sys
import os
from datetime import datetime

import requests

from typing import Any

from firebase_admin import firestore
from google.cloud.firestore_v1 import FieldFilter

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)  # Set the logging level

mapping_properties = {
    "notes_internal": "notes",
    "dealname": "name",
    "contract_type": "type",
    "job_title": "job_title",
    "location": "location",
    "start_date": "start_date",
    "closedate": "end_date",
    "dealstage": "deal_stage",
    "amount": "amount",
    "hs_object_id": "hubspot_deal_id",
    "contact_ids": "contact_ids",
    "company_ids": "company_ids",

}


def wrapper_create_deal(data, db) -> Any:
    logging.info('Received request to create deal with data: %s', data)

    ACCESS_TOKEN = "pat-eu1-39392c32-b4ba-4794-b17e-82770962effb"

    url = "https://api.hubapi.com/crm/v3/objects/deals"

    headers = {
        "Authorization": f"Bearer {ACCESS_TOKEN}",
        "Content-Type": "application/json"
    }

    # fix fields
    dt = datetime.utcfromtimestamp(data['data']['start_date'] / 1000)

    # Reset to midnight
    midnight = datetime(dt.year, dt.month, dt.day)

    # Convert back to milliseconds
    timestamp_midnight = int(midnight.timestamp() * 1000)
    data['data']['start_date'] = timestamp_midnight
    # Example: create a deal
    body = {
        "properties": data['data']
    }

    response = requests.post(url, headers=headers, data=json.dumps(body))

    if response.status_code == 201:
        logging.info('Deal created successfully in HubSpot: %s', response.json())
        return {'status': 200, 'message': 'Deal created successfully in HubSpot', 'data': response.json()}
    else:
        logging.error('Error creating deal in HubSpot: %s', response.text)
        return {'status': response.status_code, 'message': f'Error creating deal in HubSpot: {response.text}'}


def wrapper_update_deal(data, db) -> Any:
    logging.info('Received request to update deal with data: %s', data)
    ACCESS_TOKEN = "pat-eu1-39392c32-b4ba-4794-b17e-82770962effb"

    deal_id = data.get("data").get('hubspot_deal_id')
    url = f"https://api.hubapi.com/crm/v3/objects/deals/{deal_id}"

    # delete hubspot_deal_id to avoid it being sent in the properties
    del data['data']['hubspot_deal_id']

    headers = {
        "Authorization": f"Bearer {ACCESS_TOKEN}",
        "Content-Type": "application/json"
    }

    # fix fields
    dt = datetime.utcfromtimestamp(data['data']['start_date'] / 1000)

    # Reset to midnight
    midnight = datetime(dt.year, dt.month, dt.day)

    # Convert back to milliseconds
    timestamp_midnight = int(midnight.timestamp() * 1000)
    data['data']['start_date'] = timestamp_midnight
    # Example: create a deal
    body = {
        "properties": data['data']
    }

    response = requests.patch(url, headers=headers, data=json.dumps(body))

    if response.status_code == 200:
        logging.info('Deal created successfully in HubSpot: %s', response.json())
        return {'status': 200, 'message': 'Deal created successfully in HubSpot', 'data': response.json()}
    else:
        logging.error('Error creating deal in HubSpot: %s', response.text)
        return {'status': response.status_code, 'message': f'Error creating deal in HubSpot: {response.text}'}


def wrapper_sync_deal(data, db) -> Any:
    assert data is not None, 'No data provided'

    normalized_payload = normalize_payload(data)

    # iterate over each deal and perform the operations
    for hubspot_deal_id in normalized_payload:

        # iterate over each operation for the deal
        for operation in normalized_payload[hubspot_deal_id]:

            if operation == 'deal.propertyChange' and normalized_payload[hubspot_deal_id][operation]:
                properties = normalized_payload[hubspot_deal_id][operation]
                update_deal_property_update_in_bo(db, properties, hubspot_deal_id)

            elif operation == 'deal.creation' and normalized_payload[hubspot_deal_id][operation]:
                update_bo_with_hs_data(db, hubspot_deal_id)

            elif operation == 'deal.deletion' and normalized_payload[hubspot_deal_id][operation]:
                list_of_deals = normalized_payload[hubspot_deal_id][operation]
                deal = fetch_mission_order_by_hubspot_deal_id(hubspot_deal_id, db)
                _remove_association_before_delete(db, deal['id'])

                delete_deal_in_bo(db, list_of_deals, hubspot_deal_id)
                # remove associations with contacts and companies

            elif operation == 'deal.associationChange' and normalized_payload[hubspot_deal_id][operation]:
                list_associations = normalized_payload[hubspot_deal_id][operation]
                deal_association_change(db, list_associations, hubspot_deal_id)


            elif operation == 'deal.restore':
                pass  # depends on the business logic of how the BO handles deleted deals

            elif operation == 'deal.merge':
                pass  # depends on the business logic of how the BO handles merged deals

    return {'status': 200, 'message': 'Processed all operations successfully'}


def update_bo_with_hs_data(db, hubspot_deal_id):
    mission_order_collection = db.collection('mission_orders')
    hs_deal = _fetch_deal_from_hs(db, hubspot_deal_id)
    hs_mapped_properties = convert_mapped_properties(hs_deal['properties'])
    mission_order_collection.add(hs_mapped_properties)


def deal_association_change(db, list_of_associations, hubspot_deal_id):
    if not list_of_associations:
        return

    for association in list_of_associations:

        if association['associationType'] == 'DEAL_TO_CONTACT':
            handle_contact_and_deal_associations(db, association['toObjectId'], hubspot_deal_id,
                                                 association['associationRemoved'])

        elif association['associationType'] == 'DEAL_TO_COMPANY':
            handle_company_and_deal_association(db, association['toObjectId'], hubspot_deal_id,
                                                association['associationRemoved'])
        else:
            raise ValueError(f"Unknown associationType: {association['associationType']}")


def _remove_association_before_delete(db, bo_deal_id):
    query_contacts = db.collection('contacts').where(
        filter=FieldFilter('mission_order_ids', 'array_contains', bo_deal_id)).stream()
    contacts = list(query_contacts)
    for contact in contacts:
        contact_data = contact.to_dict()
        contact_data['id'] = contact.id
        db.collection('contacts').document(contact_data['id']).set(
            {'mission_order_ids': firestore.firestore.ArrayRemove([bo_deal_id])}, merge=True)

    query_companies = db.collection('companies').where(
        filter=FieldFilter('mission_order_ids', 'array_contains', bo_deal_id)).stream()
    companies = list(query_companies)
    for company in companies:
        company_data = company.to_dict()
        company_data['id'] = company.id
        db.collection('companies').document(company_data['id']).set(
            {'mission_order_ids': firestore.firestore.ArrayRemove([bo_deal_id])}, merge=True)


def handle_contact_and_deal_associations(db, contact_id, hubspot_deal_id, is_removal=False):
    # collections
    mission_order_collection = db.collection('mission_orders')
    contacts_collection = db.collection('contacts')

    deal = fetch_mission_order_by_hubspot_deal_id(hubspot_deal_id, db)

    if not deal and is_removal:
        # if the deal does not exist it's a removal operation, nothing to do
        return

    if not deal:
        # create the deal if it does not exist
        doc_ref = mission_order_collection.add({'hubspot_deal_id': str(hubspot_deal_id)})
        deal_bo_id = doc_ref[1].id
    else:
        deal_bo_id = deal['id']

    contacts = contacts_collection.where(filter=FieldFilter('hubspot_contact_id', '==', str(contact_id))).stream()

    if contacts:
        contact_doc = list(contacts)[0]
        contact_data = contact_doc.to_dict()
        contact_data['id'] = contact_doc.id

        if is_removal:

            if deal:
                mission_order_collection.document(deal_bo_id).set(
                    {'contact_ids': firestore.firestore.ArrayRemove([contact_doc.id])}, merge=True)
            contacts_collection.document(contact_data['id']).set(
                {'mission_order_ids': firestore.firestore.ArrayRemove([deal_bo_id])}, merge=True)
        else:
            mission_order_collection.document(deal_bo_id).set(
                {'contact_ids': firestore.firestore.ArrayUnion([contact_doc.id])}, merge=True)
            contacts_collection.document(contact_data['id']).set(
                {'mission_order_ids': firestore.firestore.ArrayUnion([deal_bo_id])}, merge=True)
    else:
        # create the contact if it does not exist
        pass  # TODO assuming here that all contacts exist in BO & HS are synced


def handle_company_and_deal_association(db, company_id, hubspot_deal_id, is_removal=False):
    # collections
    mission_order_collection = db.collection('mission_orders')
    companies_collection = db.collection('companies')

    deal = fetch_mission_order_by_hubspot_deal_id(hubspot_deal_id, db)

    if not deal:
        hs_deal = _fetch_deal_from_hs(db, hubspot_deal_id)
        hs_mapped_properties = convert_mapped_properties(hs_deal['properties'])
        deal_ref = mission_order_collection.add(hs_mapped_properties)
        deal_bo_id = deal_ref[1].id
        # end function here - using the updated element from HS
    else:
        deal_bo_id = deal['id']

    query = companies_collection.where('hubspot_company_id', '==', str(company_id)).stream()
    companies = list(query)
    if companies:
        company_doc = companies[0]
        company_data = company_doc.to_dict()
        company_data['id'] = company_doc.id

        if is_removal:

            if deal:
                mission_order_collection.document(deal_bo_id).set(
                    {'company_ids': firestore.firestore.ArrayRemove([company_doc.id])}, merge=True)
            companies_collection.document(company_data['id']).set(
                {'mission_order_ids': firestore.firestore.ArrayRemove([deal_bo_id])}, merge=True)
        else:
            mission_order_collection.document(deal_bo_id).set(
                {'company_ids': firestore.firestore.ArrayUnion([company_doc.id])}, merge=True)
            companies_collection.document(company_data['id']).update(
                {'mission_order_ids': firestore.firestore.ArrayUnion([deal_bo_id])})
    else:
        # create the contact if it does not exist
        pass  # TODO assuming here that all companies exist in BO & HS are synced


def normalize_payload(data):
    # centers the operation by deal using the deal id as key
    deal_operations = {}
    operations = {
        'deal.creation': [],
        'deal.deletion': [],
        'deal.associationChange': [],
        'deal.restore': [],
        'deal.merge': [],
        'deal.propertyChange': {},
    }

    for event in data:

        assert 'subscriptionType' in event, 'No subscriptionType provided'

        if 'objectId' in event:
            if event['objectId'] != deal_operations.keys():
                deal_operations[event['objectId']] = operations.copy()
        elif event['subscriptionType'] == 'deal.associationChange':
            deal_operations[event['fromObjectId']] = operations.copy()

        if event['subscriptionType'] == 'deal.propertyChange':
            deal_operations[event['objectId']]['deal.propertyChange'][event['propertyName']] = event['propertyValue']
        elif event['subscriptionType'] == 'deal.creation':
            deal_operations[event['objectId']][event['subscriptionType']].append(event)
        elif event['subscriptionType'] == 'deal.deletion':
            deal_operations[event['objectId']][event['subscriptionType']].append(event)
        elif event['subscriptionType'] == 'deal.associationChange':
            deal_operations[event['fromObjectId']][event['subscriptionType']].append(event)
        elif event['subscriptionType'] == 'deal.restore':
            deal_operations[event['objectId']][event['subscriptionType']].append(event)
        elif event['subscriptionType'] == 'deal.merge':
            deal_operations[event['objectId']][event['subscriptionType']].append(event)
        else:
            raise ValueError(f"Unknown subscriptionType: {event['subscriptionType']}")

    return deal_operations


def create_deal_in_bo(db, list_of_deals, hubspot_deal_id):
    if not list_of_deals:
        pass

    # Check if the deal already exists in BO with the same hubspot_deal_id
    mission_order_collection = db.collection('mission_orders')
    deal_store = fetch_mission_order_by_hubspot_deal_id(hubspot_deal_id, db)

    if deal_store:
        return {'status': 200, 'message': f'Deal with hubspot_deal_id {hubspot_deal_id} already exists.'}
    else:
        for deal in list_of_deals:
            hs_deal = _fetch_deal_from_hs(db, deal['objectId'])
            hs_mapped_properties = convert_mapped_properties(hs_deal['properties'])
            mission_order_collection.add(hs_mapped_properties)


def delete_deal_in_bo(db, list_of_deals, hubspot_deal_id):
    if list_of_deals:
        deal = fetch_mission_order_by_hubspot_deal_id(hubspot_deal_id, db)
        if deal:
            mission_order_collection = db.collection('mission_orders')
            mission_order_collection.document(deal['id']).delete()


def fetch_mission_order_by_hubspot_deal_id(hubspot_deal_id, db):
    mission_order_collection = db.collection('mission_orders')
    query = mission_order_collection.where(filter=FieldFilter('hubspot_deal_id', '==', str(hubspot_deal_id))).stream()
    results = list(query)
    if not results:
        return None
    else:
        doc_as_dict = results[0].to_dict()
        doc_as_dict['id'] = results[0].id
        return doc_as_dict


def update_deal_property_update_in_bo(db, properties, hubspot_deal_id):
    mission_order_collection = db.collection('mission_orders')

    # check if the deal exists in BO
    deal_stored = fetch_mission_order_by_hubspot_deal_id(hubspot_deal_id, db)
    if not deal_stored:
        # fetch from HS and create it in BO
        update_bo_with_hs_data(db, hubspot_deal_id)
    else:
        mapped_properties = convert_mapped_properties(properties)
        mapping_properties['hubspot_deal_id'] = hubspot_deal_id
        mission_order_collection.document(deal_stored['id']).set(mapped_properties, merge=True)


def _fetch_deal_from_hs(db, hubspot_deal_id, ):
    # Your HubSpot API access token
    access_token = "pat-eu1-39392c32-b4ba-4794-b17e-82770962effb"

    # HubSpot API endpoint for fetching an object by ID
    url = f"https://api.hubapi.com/crm/v3/objects/deals/{hubspot_deal_id}"

    # HTTP headers including authorization
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }

    params = {
        "associations": ["contacts", "companies"],
        "archived": "false",
        "properties": mapping_properties.keys()
    }

    # Make the GET request
    response = requests.get(url, headers=headers, params=params)

    if response.status_code == 200:
        data = response.json()

        # flat json at associations level
        company_ids = []
        contacts_ids = []

        if 'associations' in data:
            associations = data['associations']
            if 'companies' in associations and associations['companies']['results']:
                company_ids = [assoc['id'] for assoc in associations['companies']['results']]
            if 'contacts' in associations and associations['contacts']['results']:
                contacts_ids = [assoc['id'] for assoc in associations['contacts']['results']]

        # get BO ids based on HS ids
        bo_company_ids = []
        for company_id in company_ids:
            company = fetch_company_based_on_property(db, 'hubspot_company_id', company_id)
            if company:
                bo_company_ids.append(company['id'])

        bo_contact_ids = []
        for contact_id in contacts_ids:
            contact = fetch_contact_based_on_property(db, 'hubspot_contact_id', contact_id)
            if contact:
                bo_contact_ids.append(contact['id'])

        data['properties']['company_ids'] = list(set(bo_company_ids))
        data['properties']['contact_ids'] = list(set(bo_contact_ids))

        return data
    else:
        # throw an error
        raise Exception(f"Error fetching deal from HS: {response.status_code} - {response.text}")


def fetch_contact_based_on_property(db, property_name, property_value):
    contacts_collection = db.collection('contacts')
    query = contacts_collection.where(filter=FieldFilter(property_name, '==', property_value)).stream()
    results = list(query)
    if not results:
        return None
    else:
        doc_as_dict = results[0].to_dict()
        doc_as_dict['id'] = results[0].id
        return doc_as_dict


def fetch_company_based_on_property(db, property_name, property_value):
    companies_collection = db.collection('companies')
    query = companies_collection.where(filter=FieldFilter(property_name, '==', property_value)).stream()
    results = list(query)
    if not results:
        return None
    else:
        doc_as_dict = results[0].to_dict()
        doc_as_dict['id'] = results[0].id
        return doc_as_dict


def convert_mapped_properties(properties):
    converted_properties = {}
    for hs_property, value in properties.items():
        if hs_property in mapping_properties:
            bo_property = mapping_properties[hs_property]
            converted_properties[bo_property] = value
    return converted_properties
