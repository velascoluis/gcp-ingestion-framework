# GCP Ingestion framework - Batch file ingestion onprem to BigQuery

## Introduction

This repository contains an opinionated implementation of a simple GCP Batch On prem File to BigQuery Data ingestion Solution.
It uses the following GCP components:

* [**Cloud Storage**](https://cloud.google.com/storage) + [**Cloud Storage FUSE**](https://cloud.google.com/storage/docs/gcs-fuse) - For data uploading to a landing GCS bucket. GCS FUSE is an adapter that allows you to mount Cloud Storage buckets as file systems on Linux or macOS systems. It also provides a way for applications to upload and download Cloud Storage objects using standard file system semantics. Supported formats are: CSV, JSON and PARQUET
* [**Dataplex**](https://cloud.google.com/dataplex) - for landing area GCS data auto discovery and automatic registration of BigQuery external tables - including automatic schema detection.
* [**Dataform**](https://cloud.google.com/dataform) - for reading the BigQuery landing external tables, perform quality checks and materialize the tables inside BigQuery using native storage.
* [**Composer**](https://cloud.google.com/composer) - for triggering the previous dataform jobs on a fixed schedule of after an particular event is triggered (e.g. new files on bucket)



## Ingestion Workflow

The data jouney (from on-prem to BQ) is the following:

1. On a local node on your datacenter, a bucket is mounted using `GCS FUSE`. This node has  access to a NAS/SAN filesystem. 

![alt text](assets/02.png)

2. Data is copied in paralell from the SAN/NAS to the GCS FUSE filesystem using standard OS tools (e.g. `cp`). A requirement of this framework is that the data layout should conform to the [HIVE directory partitioned layout](https://cloud.google.com/bigquery/docs/hive-partitioned-queries-gcs#supported_data_layouts). Supported file formats are `JSON`,`CSV`,`AVRO`,`ORC` and `PARQUET`.
3. The mounted bucket is under a dataplex RAW Zone with a discovery job configured, so once the bucket is scanned, new external tables will be registered at BigQuery automatically.
4. Finally, a Composer DAG calls a dataform job, that reads the external BigQuery table, applies certain validations and write into another BigQuery dataset, this time as an internal table.


## Installation

From the local machine, open a terminal:
- Clone this repository:
```bash
$>  git clone https://github.com/velascoluis/gcp-ingestion-framework.git
```
- Navigate to `gcp-ingestion-framework/src/terraform/scripts-hydrated/` and execute:
```bash
$> mount_gcs_bucket_local.sh <gcp_project_id> <gcp_bucket> <mount_path>
```
The script will install FUSE if not already, create the mount directory and mount the bucket
- Copy files from your SAN/NAS to the GFUSE mounted filesystem
```bash
$> cp <san/nas filesystem path> <mount_path>
```

From GCP (Cloud Shell):
- Clone this repository:

```bash
git clone https://github.com/velascoluis/gcp-ingestion-framework.git
```

- Navigate to `gcp-ingestion-framework/src/terraform` and execute:
```bash
$> local_project_launcher.sh.sh <gcp_project_id> <gcp_region> <gcp_zone> <gcp_user_id>
```
- Navigate to `gcp-ingestion-framework/src/terraform/scripts-hydrated/` and execute:
```bash
$> source setup_ingest_framework_files.sh
```
- Navigate to `gcp-ingestion-framework/src/terraform/scripts-hydrated/ingestion_framework` and execute:
```bash
$> source launch_deploy_dataplex.sh
$> source launch_deploy_dataform.sh
$> source upload_dag.sh
```



This step will deploy all the required components on your project (see architecture below), it should take around 30 minutes.
The following items will be deployed:

* A GCS landing bucket called `ingest-stage-bucket-<PROJECT_ID>`
* A GCS code bucket called `ingest-code-bucket-<PROJECT_ID>` that contains framework code
* A GCS DAG bucket for holding Composer DAG (name varies)
* A Composer 2 environment called `<PROJECT_ID>-cc2`
* A dataproc metastore  called `ingest-dpms-<PROJECT_ID>`
* A dataplex lake called `ingestion-framework-datalake` with a RAW zone called `staging` and the landing bucket as an asset associated.
    * A BigQuery dataset called  `staging` is automaticall created
* A BigQuery dataset called `curated` 
* A dataform repository called `ingestion_framework_repo` and a workspace called `ingestion_framework_ws`

## Architecture

![alt text](assets/01.png)


The script also deploys two example tables called `customers_raw` and `service_data` with sample data, as well as dataform `.sqlx` files for reading and writing the tables from the `staging` dataset to the `curated` dataset inside BQ

## Usage

Adding a new source:

1. Copy the data to the ingest bucket - remeber to follow the HIVE folder layout
2. A new table will appear under the `staging` dataset in BigQuery
3. Create a new file under the dataform repository for reading the table in staging and writing in curated, add as many transformations and quality checks as desired
4. Send your PR to the dataform git repo
5. Once the PR is merged, new composer runs (e.g. daily) will load your data
