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
echo "${LOG_DATE} launch dataplex deploy   .."


PROJECT_ID=`"${GCLOUD_BIN}" config list --format "value(core.project)" 2>/dev/null`
GCP_REGION=`"${GCLOUD_BIN}" compute project-info describe --project ${PROJECT_ID} --format "value(commonInstanceMetadata.google-compute-default-region)" 2>/dev/null`
BQ_DATASET_NAME="curated"
RAW_GCS_BUCKET_NAME="ingest-stage-bucket-${PROJECT_ID}"


${PYTHON_BIN} -m venv local_test_env
source local_test_env/bin/activate
${PIP_BIN} install -r requirements.txt
${PYTHON_BIN} deploy_dataplex.py --project_id ${PROJECT_ID} --location ${GCP_REGION} --raw_bucket_name ${RAW_GCS_BUCKET_NAME} --curated_bq_dataset_name ${BQ_DATASET_NAME}
deactivate