#!/bin/sh
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

GCLOUD_BIN=`which gcloud`
PYTHON_BIN=`which python3`
PIP_BIN=`which pip3`

if [ "${#}" -ne 1 ]; then
    echo "Illegal number of parameters. Exiting ..."
    echo "Usage: ${0} <gcp_region>"
    echo "Exiting ..."
fi


LOG_DATE=`date`
echo "###########################################################################################"
echo "${LOG_DATE} launch dataform deploy   .."

PROJECT_ID=`"${GCLOUD_BIN}" config list --format "value(core.project)" 2>/dev/null`
GCP_REGION=${1}
#Workaround until automate this step
#GCP_REGION=`"${GCLOUD_BIN}" compute project-info describe --project ${PROJECT_ID} --format "value(commonInstanceMetadata.google-compute-default-region)" 2>/dev/null`
PROJECT_NUMBER=`"${GCLOUD_BIN}" projects list --filter="${PROJECT_ID}" --format="value(PROJECT_NUMBER)" 2>/dev/null`

DATAFORM_REPO_NAME="ingestion_framework_repo"
DATAFORM_WORKSPACE_NAME="ingestion_framework_ws"
BQ_DATASET_NAME="curated"

python3 -m venv local_test_env
source local_test_env/bin/activate
pip3 install -r requirements.txt
python3 deploy_dataform.py --project_id ${PROJECT_ID} --location ${GCP_REGION} --repository_name ${DATAFORM_REPO_NAME} --workspace_name ${DATAFORM_WORKSPACE_NAME} --bq_dataset_name ${BQ_DATASET_NAME} 
deactivate

LOG_DATE=`date`
echo "###########################################################################################"
echo "${LOG_DATE} Sleeping 1m to propagate changes   .."

sleep 60

LOG_DATE=`date`
echo "###########################################################################################"
echo "${LOG_DATE} Adding roles to the dataform SA   .."

DATAFORM_SA_ROLES_LIST="roles/bigquery.user roles/bigquery.jobUser roles/bigquery.dataEditor roles/bigquery.dataViewer roles/storage.admin"
DATAFORM_SA="service-${PROJECT_NUMBER}@gcp-sa-dataform.iam.gserviceaccount.com"
for ROLE_NAME in ${DATAFORM_SA_ROLES_LIST}
do
  LOG_DATE=`date`
  echo "${LOG_DATE} Adding role .. " ${ROLE_NAME}
  ${GCLOUD_BIN} projects add-iam-policy-binding ${PROJECT_ID} --member serviceAccount:${DATAFORM_SA} --role ${ROLE_NAME}
done


   
