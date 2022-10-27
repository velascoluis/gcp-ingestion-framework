from google.cloud import dataplex_v1
from google.api_core.exceptions import AlreadyExists
import argparse

def deploy_ingest_framework_dataplex(project_id,location,bq_dataset_name,bucket_name):

    #Create lake
    client = dataplex_v1.services.dataplex_service.DataplexServiceClient()

    lake_id = "ingestion-framework-datalake"
    metastore_id = "ingest-dpms-{}".format(project_id)
    lake_request = dataplex_v1.CreateLakeRequest(
            parent="projects/{}/locations/{}".format(project_id,location),
            lake_id=lake_id,
            lake=dataplex_v1.types.Lake(
                metastore=dataplex_v1.types.Lake.Metastore(service="projects/{}/locations/{}/services/{}".format(project_id,location,metastore_id))
            )
    )
    try:
        print("Creating lake: {} ...".format(lake_id))
        lake_response = client.create_lake(request=lake_request)
        print(lake_response.result())
    except (AlreadyExists):
        print("Lake {} already exists".format(lake_id))
    #Attach zones and assets
    zone_desc_list = [{
        "type" : "RAW",
        "location_type" : "SINGLE_REGION",
        "zone_id" : "staging",
        "assets" : [ { "type" : "STORAGE_BUCKET" , "name": "projects/{}/buckets/{}".format(project_id,bucket_name) , "asset_id" : bucket_name }  ]
    }
    #,
    #{
    #    "type" : "CURATED",
    #    "location_type" : "SINGLE_REGION",
    #    "zone_id" : "curated",
        #"assets" :   [ { "type" : "BIGQUERY_DATASET" , "name": "projects/{}/datasets/{}".format(project_id,bq_dataset_name) , "asset_id" : bq_dataset_name.replace("_","-") }  ]
    #}
    ]
    for zone_desc in zone_desc_list:
        zone = dataplex_v1.Zone()
        if 'type' in zone_desc:
            zone.type_ = zone_desc['type']
        if 'location_type' in zone_desc:
            zone.resource_spec.location_type = zone_desc['location_type']
        zone.discovery_spec.enabled = True
        #zone.discovery_spec.schedule is preset to 60mins
        if 'zone_id' in zone_desc:
            zone_request = dataplex_v1.CreateZoneRequest(
                parent="projects/{}/locations/{}/lakes/{}".format(project_id,location,lake_id),
                zone_id=zone_desc['zone_id'],
                zone=zone,
            )
            try:
                print("Creating zone: {} ...".format(zone_desc['zone_id']))
                zone_reponse = client.create_zone(request=zone_request)
                print(zone_reponse.result())
            except (AlreadyExists):
                print("Zone {} already exists".format(zone_desc['zone_id']))
        if 'assets' in zone_desc:
            for asset_desc in zone_desc['assets']:
                asset = dataplex_v1.Asset()
                asset.resource_spec.type_ = asset_desc['type']
                asset.resource_spec.name = asset_desc['name']
                #Enable asset discovery
                asset.discovery_spec.enabled = True
                asset_request = dataplex_v1.CreateAssetRequest(
                    parent="projects/{}/locations/{}/lakes/{}/zones/{}".format(project_id,location,lake_id,zone_desc['zone_id']),
                    asset_id=asset_desc['asset_id'],
                    asset = asset 
                )
                try:
                    print("Creating asset: {} ...".format(asset_desc['asset_id']))
                    asset_reponse = client.create_asset(request=asset_request)
                    print(asset_reponse.result())
                except (AlreadyExists):
                    print("Asset {} already exists".format(asset_desc['asset_id']))
    
           
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Dataplex setup for ingestion framework')
    parser.add_argument('--project_id', type=str)
    parser.add_argument('--location', type=str)
    parser.add_argument('--raw_bucket_name', type=str)
    parser.add_argument('--curated_bq_dataset_name', type=str)
    params = parser.parse_args()
    deploy_ingest_framework_dataplex(params.project_id,params.location,params.curated_bq_dataset_name,params.raw_bucket_name)