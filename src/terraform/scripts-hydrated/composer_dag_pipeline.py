# ======================================================================================
# ABOUT
# This airflow DAG calls dataform to finalise the ingestion
# ======================================================================================

import os
from airflow.models import Variable
from datetime import datetime
from airflow import models
from datetime import datetime
from airflow.utils.dates import days_ago
import string
import random

#from google.cloud.dataform_v1beta1 import WorkflowInvocation

from airflow import models
from airflow.models.baseoperator import chain
from airflow.providers.google.cloud.operators.dataform import (
    DataformCancelWorkflowInvocationOperator,
    DataformCreateCompilationResultOperator,
    DataformCreateWorkflowInvocationOperator,
    DataformGetCompilationResultOperator,
    DataformGetWorkflowInvocationOperator,
)



# .......................................................
# Variables
# .......................................................

# {{
# a) General
airflowDAGName= "ingestion-dag"
randomizerCharLength = 10 
randomVal = ''.join(random.choices(string.digits, k = randomizerCharLength))
# +
# b) Capture from Airflow variables
region = models.Variable.get("region")
pipelineID = randomVal
projectID = models.Variable.get("project_id")
repositoryID="ingestion_framework_repo"
workspaceID="ingestion_framework_ws"
# +
# }}


# .......................................................
# DAG
# .......................................................

with models.DAG(
    airflowDAGName,
    schedule_interval=None,
    start_date = days_ago(2),
    catchup=False,
) as ingestionDAG:
    create_compilation_result = DataformCreateCompilationResultOperator(
        task_id="create_compilation_result",
        project_id=projectID,
        region=region,
        repository_id=repositoryID,
        compilation_result={
            "git_commitish": "main",
            "workspace": (
                "projects/{}/locations/{}/repositories/{}/workspaces/{}".format(projectID,region,repositoryID,workspaceID)
            ),
        },
    )

    create_workflow_invocation = DataformCreateWorkflowInvocationOperator(
        task_id='create_workflow_invocation',
        project_id=projectID,
        region=region,
        repository_id=repositoryID,
        workflow_invocation={
                "compilation_result": "{{ task_instance.xcom_pull('create_compilation_result')['name'] }}"
        },
    )
    create_compilation_result >> create_workflow_invocation 


    