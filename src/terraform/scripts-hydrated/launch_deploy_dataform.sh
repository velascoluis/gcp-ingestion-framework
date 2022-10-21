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


LOG_DATE=`date`
echo "###########################################################################################"
echo "${LOG_DATE} launch dataform deploy   .."

PROJECT_ID=`"${GCLOUD_BIN}" config list --format "value(core.project)" 2>/dev/null`
GCP_REGION=`"${GCLOUD_BIN}" compute project-info describe --project ${PROJECT_ID} --format "value(commonInstanceMetadata.google-compute-default-region)" 2>/dev/null`


DATAFORM_REPO_NAME="ingestion_framework_repo"
DATAFORM_WORKSPACE_NAME="ingestion_framework_ws"
BQ_DATASET_NAME="curated"

python3 -m venv local_test_env
source local_test_env/bin/activate
pip3 install -r requirements.txt
python3 deploy_dataform.py --project_id ${PROJECT_ID} --location ${GCP_REGION} --repository_name ${DATAFORM_REPO_NAME} --workspace_name ${DATAFORM_WORKSPACE_NAME} --bq_dataset_name ${BQ_DATASET_NAME} 
deactivate
