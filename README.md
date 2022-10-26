# Batch On prem to BigQuery GCP Ingestion framework

## Introduction

This repository contains an opinionated implementation of a GCP Batch On prem File to BigQuery Data ingestion Solution.
It uses the following GCP components:

* GCS bucket + GFUSE - To upload data from a local machine, mounting the GCS bucket as an external filesystem. Supported formats are: CSV, JSON and PARQUET
* Dataplex - for data auto discovery and automatic registration of BigQuery external tables.
* Dataform - for reading the BQ external tables, perform quality checks and materilize the tables inside BigQuery.
* Composer - for triggering the dataform jobs.


## Workflow

1. On a local node, a bucket is mounted using GFUSE. Ideally this node has also access to a NAS/SAN filesystem.
2. Data is copied in paralel from the SAN/NAS to the GFUSE filesystem. The data layout should conform to the HIVE directory layout. Supported file formats are JSON,CSV and PARQUET.
3. The mounted bucket is under a dataplex RAW Zone with a discovery job configured, so once the bucket is scanned, new external tables will appear at BigQuery automatically.
4. A Composer DAG calls a dataform job, that reads the external BQ table, applies certain validations and write into another BigQuery dataset, this time as an internal table.


## Installation

From the local machine, open a terminal:
- Clone this repository:
```bash
$>  git clone https://github.com/velascoluis/gcp-ingestion-framework.git
```
- Navigate to `gcp-ingestion-framework/src/terraform/scripts-hydrated/` and execute:
```bash
$> mount_gcs_bucket_local.sh <gcp_project_id> <gcp_bucket> <path>
```
- Copy files from your SAN/NAS to the GFUSE mounted filesystem


From GCP (Cloud Shell):
- Clone this repository:

```bash
git clone https://github.com/velascoluis/gcp-ingestion-framework.git
```

- Navigate to `gcp-ingestion-framework/src/terraform` and execute:
```bash
$> local_project_launcher.sh.sh <gcp_project_id> <gcp_region> <gcp_zone> <gcp_user_id>
```
This step will deploy all the required components on your project, it should take around 30 minutes.

## Usage

Trigger the Composer DAG


## Architecture

![alt text](assets/01.png)