# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`
import json
import logging
import os

from firebase_functions import https_fn, options
from firebase_functions.options import set_global_options
from firebase_admin import initialize_app, firestore

from utils.wrappers import wrapper_sync_deal, wrapper_create_deal, wrapper_update_deal

set_global_options(max_instances=1)
initialize_app()

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)  # Set the logging level
db = firestore.client()


@https_fn.on_request(cors=options.CorsOptions(cors_origins="*", cors_methods=["post"]))
def sync_deal(req: https_fn.Request) -> https_fn.Response:
    if isinstance(req.data, bytes):
        data = json.loads(req.data.decode("utf-8"))
    else:
        data = req.data  # Already a dict

    logging.info('Received request with data: %s', data)
    return wrapper_sync_deal(data, db)


@https_fn.on_request(cors=options.CorsOptions(cors_origins="*", cors_methods=["post"]))
def create_deal(req: https_fn.Request) -> https_fn.Response:
    if isinstance(req.data, bytes):
        data = json.loads(req.data.decode("utf-8"))
    else:
        data = req.data
    return wrapper_create_deal(data, db)


@https_fn.on_request(cors=options.CorsOptions(cors_origins="*", cors_methods=["post"]))
def update_deal(req: https_fn.Request) -> https_fn.Response:
    if isinstance(req.data, bytes):
        data = json.loads(req.data.decode("utf-8"))
    else:
        data = req.data
    return wrapper_update_deal(data, db)
