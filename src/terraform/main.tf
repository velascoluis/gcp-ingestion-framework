/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/******************************************
Local variables declaration
 *****************************************/

locals {
project_id                  = "${var.gcp_project_id}"
admin_upn_fqn               = "${var.gcp_user_id}"
location                    = "${var.gcp_region}"
zone                        = "${var.gcp_zone}"
location_multi              = upper(substr("${local.location}",0,2))
umsa                        = "ingest-sa"
umsa_fqn                    = "${local.umsa}@${local.project_id}.iam.gserviceaccount.com"
ingest_stage_bucket         = "ingest-stage-bucket-${local.project_id}"
ingest_code_bucket          = "ingest-code-bucket-${local.project_id}"
vpc_nm                      = "ingest-vpc-${local.project_id}"
ingest_subnet_nm            = "ingest-snet"
ingest_subnet_cidr          = "10.0.0.0/16"
psa_ip_length               = 16
bq_ds_raw                   = "raw"
bq_ds_curated               = "curated"
composer_img_version        = "composer-2.0.29-airflow-2.2.5"
cloud_scheduler_timezone    = "America/Chicago"
dpms_nm                     = "ingest-dpms-${local.project_id}"
}



/******************************************
 Enable Google APIs in parallel
 *****************************************/

resource "google_project_service" "enable_orgpolicy_google_apis" {
  project = local.project_id
  service = "orgpolicy.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "enable_compute_google_apis" {
  project = local.project_id
  service = "compute.googleapis.com"
  disable_dependent_services = true
}



resource "google_project_service" "enable_bigquery_google_apis" {
  project = local.project_id
  service = "bigquery.googleapis.com"
  disable_dependent_services = true
  
}

resource "google_project_service" "enable_bigqueryconnection_google_apis" {
  project = local.project_id
  service = "bigqueryconnection.googleapis.com"
  disable_dependent_services = true
  
}


resource "google_project_service" "enable_storage_google_apis" {
  project = local.project_id
  service = "storage.googleapis.com"
  disable_dependent_services = true
  
}


resource "google_project_service" "enable_logging_google_apis" {
  project = local.project_id
  service = "logging.googleapis.com"
  disable_dependent_services = true
  
}

resource "google_project_service" "enable_monitoring_google_apis" {
  project = local.project_id
  service = "monitoring.googleapis.com"
  disable_dependent_services = true
  
}
resource "google_project_service" "enable_servicenetworking_google_apis" {
  project = local.project_id
  service = "servicenetworking.googleapis.com"
  disable_dependent_services = true
  
}


resource "google_project_service" "enable_composer_google_apis" {
  project = local.project_id
  service = "composer.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "enable_dataplex_google_apis" {
  project = local.project_id
  service = "dataplex.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "enable_dataform_google_apis" {
  project = local.project_id
  service = "dataform.googleapis.com"
  disable_dependent_services = true
}


resource "google_project_service" "enable_metastore_google_apis" {
  project = local.project_id
  service = "metastore.googleapis.com"
  disable_dependent_services = true
}



/*******************************************
Introducing sleep to minimize errors from
dependencies having not completed
********************************************/
resource "time_sleep" "sleep_after_api_enabling" {
  create_duration = "60s"
  depends_on = [
    google_project_service.enable_orgpolicy_google_apis,
    google_project_service.enable_compute_google_apis,
    google_project_service.enable_bigquery_google_apis,
    google_project_service.enable_bigqueryconnection_google_apis,
    google_project_service.enable_storage_google_apis,
    google_project_service.enable_servicenetworking_google_apis,
    google_project_service.enable_composer_google_apis,
    google_project_service.enable_dataplex_google_apis,
    google_project_service.enable_dataform_google_apis,
    google_project_service.enable_metastore_google_apis,

  ]
}


/******************************************
 Prepare environment (only Qwiklabs)
 *****************************************/

resource "null_resource" "install_gcloud" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = "rm -rf /root/google-cloud-sdk; curl https://sdk.cloud.google.com > install.sh; bash install.sh --disable-prompts; source /root/google-cloud-sdk/path.bash.inc"
  }
  depends_on = [time_sleep.sleep_after_api_enabling]
}



resource "null_resource" "install_docker" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = "curl -fsSL get.docker.com -o get-docker.sh && sh get-docker.sh"
  }
  depends_on = [time_sleep.sleep_after_api_enabling,null_resource.install_gcloud]
}


resource "null_resource" "install_wget" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = "apt-get update &&  apt-get install wget"
  }
  depends_on = [time_sleep.sleep_after_api_enabling,null_resource.install_wget]
}



/******************************************
Create User Managed Service Account (UMSA)
 *****************************************/
module "umsa_creation" {
  source     = "terraform-google-modules/service-accounts/google"
  project_id = local.project_id
  names      = ["${local.umsa}"]
  display_name = "User Managed Service Account"
  description  = "User Managed Service Account for Ingestion framework"
  depends_on = [time_sleep.sleep_after_api_enabling,null_resource.install_gcloud,null_resource.install_docker,null_resource.install_wget]
}



/******************************************
Grant IAM roles to User Managed Service Account
 *****************************************/

module "umsa_role_grants" {
  source                  = "terraform-google-modules/iam/google//modules/member_iam"
  service_account_address = "${local.umsa_fqn}"
  prefix                  = "serviceAccount"
  project_id              = local.project_id
  project_roles = [
    
    "roles/iam.serviceAccountUser",
    "roles/iam.serviceAccountTokenCreator",
    "roles/storage.objectAdmin",
    "roles/storage.admin",
    "roles/bigquery.dataEditor",
    "roles/bigquery.admin",
    "roles/logging.logWriter",
    "roles/viewer",
    "roles/composer.worker",
    "roles/composer.admin",
    "roles/dataform.admin",
    
  ]
  depends_on = [
    module.umsa_creation
  ]
}


/******************************************************
Grant Service Account Impersonation privilege to yourself/Admin User
 ******************************************************/

module "umsa_impersonate_privs_to_admin" {
  source  = "terraform-google-modules/iam/google//modules/service_accounts_iam/"
  service_accounts = ["${local.umsa_fqn}"]
  project          = local.project_id
  mode             = "additive"
  bindings = {
    "roles/iam.serviceAccountUser" = [
      "user:${local.admin_upn_fqn}"
    ],
    "roles/iam.serviceAccountTokenCreator" = [
      "user:${local.admin_upn_fqn}"
    ]

  }
  depends_on = [
    module.umsa_creation
  ]
}

/******************************************************
Grant IAM roles to Admin User/yourself
 ******************************************************/

module "administrator_role_grants" {
  source   = "terraform-google-modules/iam/google//modules/projects_iam"
  projects = ["${local.project_id}"]
  mode     = "additive"

  bindings = {
    "roles/storage.admin" = [
      "user:${local.admin_upn_fqn}",
    ]
    "roles/bigquery.admin" = [
      "user:${local.admin_upn_fqn}",
    ]
    "roles/bigquery.user" = [
      "user:${local.admin_upn_fqn}",
    ]
    "roles/bigquery.dataEditor" = [
      "user:${local.admin_upn_fqn}",
    ]
    "roles/bigquery.jobUser" = [
      "user:${local.admin_upn_fqn}",
    ]
    "roles/composer.environmentAndStorageObjectViewer" = [
      "user:${local.admin_upn_fqn}",
    ]
    "roles/iam.serviceAccountUser" = [
      "user:${local.admin_upn_fqn}",
    ]
    "roles/iam.serviceAccountTokenCreator" = [
      "user:${local.admin_upn_fqn}",
    ]
    "roles/composer.admin" = [
      "user:${local.admin_upn_fqn}",
    ]
     "roles/compute.networkAdmin" = [
      "user:${local.admin_upn_fqn}",
    ]
  }
  depends_on = [
    module.umsa_role_grants,
    module.umsa_impersonate_privs_to_admin
  ]
  }

/*******************************************
Introducing sleep to minimize errors from
dependencies having not completed
********************************************/
resource "time_sleep" "sleep_after_identities_permissions" {
  create_duration = "60s"
  depends_on = [
    module.umsa_creation,
    module.umsa_role_grants,
    module.umsa_impersonate_privs_to_admin,
    module.administrator_role_grants
  ]
}

/************************************************************************
Create VPC network, subnet & reserved static IP creation
 ***********************************************************************/
module "vpc_creation" {
  source                                 = "terraform-google-modules/network/google"
  project_id                             = local.project_id
  network_name                           = local.vpc_nm
  routing_mode                           = "REGIONAL"

  subnets = [
    {
      subnet_name           = "${local.ingest_subnet_nm}"
      subnet_ip             = "${local.ingest_subnet_cidr}"
      subnet_region         = "${local.location}"
      subnet_range          = local.ingest_subnet_cidr
      subnet_private_access = true
    }
  ]
  depends_on = [
    time_sleep.sleep_after_identities_permissions
  ]
}

resource "google_compute_global_address" "reserved_ip_for_psa_creation" { 
  provider      = google
  name          = "private-service-access-ip"
  purpose       = "VPC_PEERING"
  network       =  "projects/${local.project_id}/global/networks/ingest-vpc-${local.project_id}"
  address_type  = "INTERNAL"
  prefix_length = local.psa_ip_length
  
  depends_on = [
    module.vpc_creation
  ]
}

resource "google_service_networking_connection" "private_connection_with_service_networking" {
  network                 =  "projects/${local.project_id}/global/networks/ingest-vpc-${local.project_id}"
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.reserved_ip_for_psa_creation.name]

  depends_on = [
    module.vpc_creation,
    google_compute_global_address.reserved_ip_for_psa_creation
  ]
}

/******************************************
Create Firewall rules 
 *****************************************/

resource "google_compute_firewall" "allow_intra_snet_ingress_to_any" {
  project   = local.project_id 
  name      = "allow-intra-snet-ingress-to-any"
  network   = local.vpc_nm
  direction = "INGRESS"
  source_ranges = [local.ingest_subnet_cidr]
  allow {
    protocol = "all"
  }
  description        = "Creates firewall rule to allow ingress from within ingest subnet on all ports, all protocols"
  depends_on = [
    module.vpc_creation, 
    module.administrator_role_grants
  ]
}

/*******************************************
Introducing sleep to minimize errors from
dependencies having not completed
********************************************/
resource "time_sleep" "sleep_after_network_and_firewall_creation" {
  create_duration = "60s"
  depends_on = [
    module.vpc_creation,
    google_compute_firewall.allow_intra_snet_ingress_to_any
  ]
}

/******************************************
Create Storage bucket 
 *****************************************/

resource "google_storage_bucket" "ingest_stage_bucket_creation" {
  project                           = local.project_id 
  name                              = local.ingest_stage_bucket
  location                          = local.location
  uniform_bucket_level_access       = true
  force_destroy                     = true
  depends_on = [
      time_sleep.sleep_after_network_and_firewall_creation
  ]
}


resource "google_storage_bucket" "ingest_code_bucket_creation" {
  project                           = local.project_id 
  name                              = local.ingest_code_bucket
  location                          = local.location
  uniform_bucket_level_access       = true
  force_destroy                     = true
  depends_on = [
      time_sleep.sleep_after_network_and_firewall_creation
  ]
}





/*******************************************
Introducing sleep to minimize errors from
dependencies having not completed
********************************************/

resource "time_sleep" "sleep_after_bucket_creation" {
  create_duration = "60s"
  depends_on = [
    google_storage_bucket.ingest_stage_bucket_creation, google_storage_bucket.ingest_code_bucket_creation
  ]
}


/******************************************
Copy of datasets to bucket
 ******************************************/

resource "google_storage_bucket_object" "customer_datasets_upload_to_gcs" {
  for_each = fileset("${path.module}/sample_data/customers/", "*")
  source = "${path.module}/sample_data/customers/${each.value}"
  name = "customers_raw/${each.value}"
  bucket = "${local.ingest_stage_bucket}"
  depends_on = [
    time_sleep.sleep_after_bucket_creation
  ]
}

resource "google_storage_bucket_object" "service_datasets_upload_to_gcs" {
  for_each = fileset("${path.module}/sample_data/service/", "*")
  source = "${path.module}/sample_data/service/${each.value}"
  name = "service_raw/${each.value}"
  bucket = "${local.ingest_stage_bucket}"
  depends_on = [
    time_sleep.sleep_after_bucket_creation
  ]
}


resource "google_storage_bucket_object" "scripts_dir_upload_to_gcs" {
  for_each = fileset("${path.module}/scripts-hydrated/", "*")
  source = "${path.module}/scripts-hydrated/${each.value}"
  name = "${each.value}"
  bucket = "${local.ingest_code_bucket}"
  depends_on = [
    time_sleep.sleep_after_bucket_creation
  ]
}




/*******************************************
Introducing sleep to minimize errors from
dependencies having not completed
********************************************/

resource "time_sleep" "sleep_after_network_and_storage_steps" {
  create_duration = "60s"
  depends_on = [
      time_sleep.sleep_after_network_and_firewall_creation,
      time_sleep.sleep_after_bucket_creation,
      google_storage_bucket_object.customer_datasets_upload_to_gcs,
      google_storage_bucket_object.service_datasets_upload_to_gcs,
  ]
}



/******************************************
BigQuery dataset creation
******************************************/


resource "google_bigquery_dataset" "bq_dataset_ds_curated_creation" {
  dataset_id                  = local.bq_ds_curated
  location                    = local.location
}



/********************************************************
Create Composer Environment
********************************************************/

data "google_compute_default_service_account" "default" {
  depends_on = [time_sleep.sleep_after_api_enabling]
}

# IAM role grants to Google Managed Service Account for Compute Engine (for Cloud Composer 2 to download images)

resource "google_project_iam_member" "grant_editor_default_compute" {
    project = "${local.project_id}"
    role =  "roles/editor"
    member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
  depends_on = [
        module.administrator_role_grants,
        time_sleep.sleep_after_network_and_storage_steps,
        time_sleep.sleep_after_api_enabling
  ] 
}

# IAM role grants to Google Managed Service Account for Cloud Composer 2
module "gmsa_role_grants_cc" {
  source                  = "terraform-google-modules/iam/google//modules/member_iam"
  service_account_address = format("%s-%s@%s","service",split("-", "${data.google_compute_default_service_account.default.email}")[0],"cloudcomposer-accounts.iam.gserviceaccount.com")
   #The split part deals with extracting the project nbr from the default compute engine service account
  prefix                  = "serviceAccount"
  project_id              = local.project_id
  project_roles = [
    
    "roles/composer.ServiceAgentV2Ext"

  ]
   depends_on = [
        google_project_iam_member.grant_editor_default_compute
  ]  
}

resource "google_composer_environment" "cloud_composer_env_creation" {
  name   = "${local.project_id}-cc2"
  region = local.location
  provider = google

  config {
    software_config {
      image_version = local.composer_img_version 
      env_variables = {
        AIRFLOW_VAR_PROJECT_ID = "${local.project_id}"
        AIRFLOW_VAR_PROJECT_NBR = "${local.project_id}"
        AIRFLOW_VAR_REGION = "${local.location}"
        AIRFLOW_VAR_SUBNET = "${local.ingest_subnet_nm}"
        AIRFLOW_VAR_BQ_DATASET_RAW = "${local.bq_ds_raw}"
        AIRFLOW_VAR_BQ_DATASET_CURATED ="${local.bq_ds_curated}"
        AIRFLOW_VAR_UMSA_FQN = "${local.umsa_fqn}"
        
      }
    }

    node_config {
      network    = local.vpc_nm
      subnetwork = local.ingest_subnet_nm
      service_account = local.umsa_fqn
    }
  }

  depends_on = [
        module.administrator_role_grants,
        time_sleep.sleep_after_network_and_storage_steps,
        time_sleep.sleep_after_api_enabling
  ] 

  timeouts {
    create = "90m"
  } 
}


/******************************************
Create Dataproc Metastore
******************************************/
resource "google_dataproc_metastore_service" "datalake_metastore_creation" {
  service_id = local.dpms_nm
  location   = local.location
  tier       = "DEVELOPER"
  network    = "projects/${local.project_id}/global/networks/${local.vpc_nm}"

  maintenance_window {
    hour_of_day = 2
    day_of_week = "SUNDAY"
  }

  hive_metastore_config {
    version = "3.1.2"
    endpoint_protocol = "GRPC"
  }

metadata_integration {
  data_catalog_config {
    enabled = true
  }
}

  depends_on = [
        module.administrator_role_grants,
        time_sleep.sleep_after_network_and_storage_steps,
        time_sleep.sleep_after_api_enabling
  ] 
}



/*******************************************
Introducing sleep to minimize errors from
dependencies having not completed
********************************************/


resource "time_sleep" "sleep_after_composer_creation" {
  create_duration = "60s"
  depends_on = [
      google_composer_environment.cloud_composer_env_creation
  ]
}



/******************************************
DONE
******************************************/