# cp4ba-wfps

Utilities for IBM Cloud Pak® for Business Automation

<i>Last update: 2026-07-09</i> use '<b>main</b>' for latest update (see changelog.md for details)


This repository contains a series of examples and tools for creating and configuring Workflow Process Service (WFPS) in IBM Cloud Pak for Business Automation deployment.

Two scenarios are described, one with non-federated servers and one with federated servers.

For both scenarios we will use a 'starter' type installation.

The second scenario is preparatory to a more complex configuration which requires the presence of a federated BAW runtime instance as well.

The BAW in its '<b>/ProcessPortal</b>' dashboard will offer the applications/tasks running on the other federated WFPSs.

<b>**WARNING**</b>:

++++++++++++++++++++++++++++++++++++++++++++++++
<br>
<i>
This software and the configurations contained in the repository MUST be considered as examples for educational purposes.
<br>
Do not use in a production environment without making your own necessary modifications.
</i>
<br>
++++++++++++++++++++++++++++++++++++++++++++++++

Please use '-stable' versions, the main branch may contain untested functionality.

See '[Prerequisites](#Prerequisites)' section before deploying WFPS servers.

If you want run a WFPS instance in federated environment using 'Process Federation Server' in container (same namespace) you must configure a <b>PFS</b> deployment; use guidance and tools from repository [https://github.com/marcoantonioni/cp4ba-process-federation-server](https://github.com/marcoantonioni/cp4ba-process-federation-server) ...will be public soon.

You may deploy non-federated WFPS into same namespace of federated WFPS server.

All examples make use of dynamic storage, the presence of a storage class for dynamic volume allocation is required.

The tools '<i>oc</i>' and '<i>jq</i>' are required.

The '<i>openssl</i>' tool is required only for the integration scenario with external services protected by TLS transports.

All examples and scripts are only available for Linux boxes with <i>bash</i> shell.

<b>WARNING</b>: before run any command please update configuration files with your values.

## Description of configuration files and variables

https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/25.0.1?topic=reference-cp4ba-workflow-process-service-runtime-parameters

PFS

https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/25.0.1?topic=reference-cp4ba-process-federation-server-parameters

WFPS example configuration file variables
```
# WfPS server name
export WFPS_NAME="wfps-demo-pfs-1"
export WFPS_RUNTIME_TEMPLATE="../templates26/wfps-cr-ext-db.yaml"

# WfPS license type: non-production | production
export WFPS_LICENSE_TYPE="production"

# WfPS target environment
export WFPS_NAMESPACE=${CP4BA_INST_NAMESPACE}
export WFPS_STORAGE_CLASS=${CP4BA_INST_SC_FILE}
export WFPS_STORAGE_CLASS_BLOCK=${CP4BA_INST_SC_BLOCK}
export WFPS_APP_VER=${CP4BA_INST_APPVER}
export WFPS_APP_TAG=${WFPS_APP_VER}

# WfPS admin user credentials
export WFPS_ADMINUSER="cpadmin"
export WFPS_ADMINPASSWORD=""

# WfPS resources
export WFPS_REPLICAS=1
export WFPS_LIMITS_CPU=3000m
export WFPS_LIMITS_MEMORY=3072Mi
export WFPS_REQS_CPU=500m
export WFPS_REQS_MEMORY=1024Mi

# WfPS trusted certificates (list of comma separated secret 'names' containing TLS certificates)
# example (keep single quotas for each name): WFPS_TLS_SECRET_NAMES="'secret-name-1','secret-name-2'"
export WFPS_TLS_SECRET_NAMES="'wfps-trusted-cert1'"

# WfPS database (must be one in .sql statements file references by CP4BA_INST_DB_1_TEMPLATE)
export WFPS_EXT_DB_NAME="wfpsdb1"
export WFPS_EXT_DB_TEMPLATE="../templates-sql/db-statements-wfps1.sql"
export WFPS_EXT_DB_USER_NAME="wfps_user"
export WFPS_EXT_DB_USER_PASSWORD="dem0s"
export WFPS_EXT_DB_SERVER="${CP4BA_INST_DB_1_SERVER_NAME_SSL}"
export WFPS_EXT_DB_ENABLE_SSL="true"
export WFPS_EXT_DB_CERT_SSL="${CP4BA_INST_DB_1_TLS_CERTS_SECRET_NAME}"
export WFPS_EXT_DB_PORT=${CP4BA_INST_DB_SERVER_PORT}
export WFPS_EXT_DB_CREDENTIAL_SECRET="${WFPS_EXT_DB_NAME}-secret"
export WFPS_EXT_DB_CONN_POOL_MIN=50
export WFPS_EXT_DB_CONN_POOL_MAX=200

# WfPS PFS federation
export WFPS_FEDERATE=true
export WFPS_FEDERATE_TEXTSEARCH=${WFPS_FEDERATE}
export WFPS_FEDERATE_TEXTSEARCH_SIZE="10Gi"
export WFPS_FEDERATE_TEXTSEARCHSIZE_SNAP="2Gi"

```

Trusted certificates configuration file variables.
The script will create a tls type secret containing the public key obtained from endpoint url.
```
TCERT_ENDPOINT_URL_1=<hostname-and-port-of-target-service> # eg: cpd-cp4ba.apps.1234567890.cloud.techzone.ibm.com:443
TCERT_SECRET_NAME_1=<secret-name> # any name k8s compatible

# add as you like with sequential number as suffix
TCERT_ENDPOINT_URL_2=
TCERT_SECRET_NAME_2=
```

## Demo applications

The demo applications in this repository have been developed using CP4BA BAStudio v23.0.2

For each application both source code (.twx) and deployable package (.zip) are in 'apps' folder

The app SimpleDemoWfPS implements a process named 'SimpleProcess'.
This process can be started either via '/Workplace' browser or via REST service (see example interaction with cUrl).
The process implements two tasks associated respectively with the Requester role and the Validator role (see TeamBindings for associated users).

The app SimpleDemoStraightThroughProcessingWfPS implements a process named 'SimpleSTPProcess'.
This process can be started either via '/Workplace' browser or via REST service (see example interaction with cUrl).
The 'Straight Through Processing' type process does not implement tasks, it starts and ends independently.

Both processes write to the server log file (to consult the logs see example in the 'Spare commands' section

## Prerequisites

To continue with the deployment examples, the following prerequisites must be met:

- The destination namespace must contain at least a running Foundation deployment.

## Examples of deployment

For v26
[For v26](./EXAMPLES-v26.md)

For v26
[For v25 and prev](./EXAMPLES-v25.md)


# References

Installing a CP4BA Workflow Process Service production deployment [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/25.0.1?topic=ipd-installing-cp4ba-workflow-process-service-runtime-production-deployment](https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/25.0.1?topic=ipd-installing-cp4ba-workflow-process-service-runtime-production-deployment)

Federating IBM Business Automation Workflow on containers [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/25.0.1?topic=deployment-federating-business-automation-workflow-in-cp4ba](https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/25.0.1?topic=deployment-federating-business-automation-workflow-in-cp4ba)

TOOLS

Openshift CLI
[https://docs.openshift.com/container-platform/4.14/cli_reference/openshift_cli/getting-started-cli.html](https://docs.openshift.com/container-platform/4.14/cli_reference/openshift_cli/getting-started-cli.html)

JQ
[https://jqlang.github.io/jq](https://jqlang.github.io/jq)


For other free tools related to IBM Cloud Pak for Business Automation you can search for projects with the prefix 'cp4ba-' in my public git [https://github.com/marcoantonioni](https://github.com/marcoantonioni)

