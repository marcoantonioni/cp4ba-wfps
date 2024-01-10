# cp4ba-wfps

<i>Last update: 2024-01-10</i> use '<b>1.1.0-stable</b>'
```
bug fixed:
- wrong tag for federated CR

new functionalities:
- CR in yaml format generated into 'output' folder
- new run option '-g' for generate CR only without deployment
```


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

WFPS configuration file variables
```
WFPS_NAME=<name-of-cr> # any name k8s compatible
WFPS_NAMESPACE=<target-namespace> # any name k8s compatible
WFPS_STORAGE_CLASS=<name-of-file-type-storage-class> # select one available from your OCP cluster
WFPS_APP_VER=<cp4ba-version-number> (eg: 23.0.2)
WFPS_APP_TAG="${WFPS_APP_VER}" # do not modify
WFPS_FEDERATE=<true|false> # if true the deployment scripts generate the required tags

# self explaining
WFPS_LIMITS_CPU=750m
WFPS_LIMITS_MEMORY=2048Mi
WFPS_REQS_CPU=500m
WFPS_REQS_MEMORY=1024Mi

# federation values
WFPS_STORAGE_CLASS_BLOCK=<name-of-block-type-storage-class> # select one available from your OCP cluster
WFPS_FEDERATE_TEXTSEARCH=<true|false> # if true the deployment scripts generate the required tags
WFPS_FEDERATE_TEXTSEARCH_SIZE="10Gi" # size of storage used by PVC
WFPS_FEDERATE_TEXTSEARCHSIZE_SNAP="2Gi"  # size of storage used by PVC
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

The demo applications in this repository have been developer using CP4BA BAStudio v23.0.2

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

## 1. WFPS Deployments

Examples for WFPS server deployments.

### 1.1 Simple WFPS deploy (dedicated PostgreSQL database built by operator)
```
# WFPS deploy (non federated configuration)
# REMEMBER: adapt the properties file to your environment

# 1. deploy WFPS
time ./wfps-deploy.sh -c ../configs/wfps1.properties
```

### 1.2 Simple WFPS deploy with trusted certificates (dedicated PostgreSQL database built by operator)
```
# WFPS deploy using trusted certificates (non federated configuration)
# REMEMBER: adapt the properties file to your environment

# 1. create secret with remote server certificate
time ./wfps-add-secrets-trusted-certs.sh -c ../configs/wfps2.properties -t ../configs/trusted-certs.properties

# 2. deploy WFPS and add trusted certificates list
time ./wfps-deploy.sh -c ../configs/wfps2.properties -t ../configs/trusted-certs.properties
```

### 1.3 show WFPS infos

```
./wfps-export-env-vars-to-file.sh -c ../configs/wfps1.properties
```

### 1.4 show WFPS server logs

```
./wfps-export-env-vars-to-file.sh -c ../configs/wfps1.properties 

# warning: source using generated vars file
source ./exp-wfps-1.vars

oc rsh -n ${WFPS_NAMESPACE} ${WFPS_NAME}-wfps-runtime-server-0 tail -n 1000 -f /logs/application/${WFPS_NAME}-wfps-runtime-server-0/liberty-message.log
```

## 2. Application deployment

Example for installing applications.

### 2.1 Deploy application
```
# install application using WFPS runtime described in 'wfps1.properties'
time ./wfps-install-application.sh -c ../configs/wfps1.properties -a ../apps/SimpleDemoWfPS.zip

# install application using WFPS runtime described in 'wfps2.properties'
time ./wfps-install-application.sh -c ../configs/wfps2.properties -a ../apps/SimpleDemoStraightThroughProcessingWfPS.zip
```

## 3. Configure application Team Bindings

Applications are configured with TemBindings ready for 'cpadmin' and 'cp4admin' users.

In the case of a 'starter' type CP4BA deployment the local LDAP is configured for user1, user2, etc...

The example configurations assume the presence of these user names, in case you can modify the list of users in the properties file.

### 3.1 Update team bindings

For team bindings configuration see file './configs/team-bindings-app-1.properties'

```
# parameters:
# -c path to wfps configuration file
# -t path to team bindings configuration file
# -r [optional] remove actual team binding configuration 

time ./wfps-update-team-bindings.sh -c ../configs/wfps1.properties -t ../configs/team-bindings-app-1.properties -r
```

## 4.1 Update application

To activate|deactivate or make as 'default' a snapshot
```
# deactivate preinstalled demo app, force process instances suspension
time ./wfps-update-application.sh -c ../configs/wfps1.properties -a HSS -b RHSV180 -s deactivate -f

# activate preinstalled demo app
time ./wfps-update-application.sh -c ../configs/wfps1.properties -a HSS -b RHSV180 -s activate

# deactivate app, dont force (may result in error if unique snapshot)
time ./wfps-update-application.sh -c ../configs/wfps1.properties -a SDWPS -b 0.5 -s deactivate

# deactivate demo app, force process instances suspension
time ./wfps-update-application.sh -c ../configs/wfps1.properties -a SDWPS -b 0.5 -s deactivate -f

# activate app
time ./wfps-update-application.sh -c ../configs/wfps1.properties -a SDWPS -b 0.5 -s activate
```

## 4.2 Remove snapshot

Prerequisite: The snapshot must be deactivated
```
# remove app, no force (may result in error if unique snapshot)
time ./wfps-remove-application.sh -c ../configs/wfps1.properties -a SDWPS -b 0.5

# remove app, force
time ./wfps-remove-application.sh -c ../configs/wfps1.properties -a SDWPS -b 0.5 -f

# remove preinstalled demo app, force
time ./wfps-remove-application.sh -c ../configs/wfps1.properties -a HSS -b RHSV180 -f

```

## 5. Examples of REST services invocations using curl

Below are some examples for invoking REST services exposed by the demo applications deployed in WFPS.

The script 'wfps-export-env-vars-to-file.sh' exports the environment variables necessary to interact via 'cUrl' with REST services into a support file.

### 5.1 Interact with services from 'SimpleDemoWFPS' application

Login in browser to '<b>/Workplace</b>' as a user defined in TeamBindings role to interact with tasks.
To administer the WfPS runtime login in browser to '<b>/ProcessAdmin</b>' as admin user defined in configuration variable '<i>WFPS_ADMINUSER</i>'.


```
# generate and source env vars
./wfps-export-env-vars-to-file.sh -c ../configs/wfps1.properties 
source ./exp-wfps-1.vars

# call a service
curl -sk -u ${WFPS_ADMINUSER}:${WFPS_ADMINPASSWORD} -H 'accept: application/json' -H 'content-type: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X POST ${WFPS_EXTERNAL_BASE_URL}/automationservices/rest/SDWPS/SimpleDemoREST/startService -d '{"request": {"name":"Marco", "counter": 10, "flag": true}}' | jq .

# call a service that start a new process instance
curl -sk -u ${WFPS_ADMINUSER}:${WFPS_ADMINPASSWORD} -H 'accept: application/json' -H 'content-type: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X POST ${WFPS_EXTERNAL_BASE_URL}/automationservices/rest/SDWPS/SimpleDemoREST/startProcess -d '{"request": {"name":"Marco in process", "counter": 20, "flag": true}}' | jq .

```
### 5.2 Interact with services from 'SimpleDemoStraightThroughProcessingWfPS' application
```
# generate and source env vars
./wfps-export-env-vars-to-file.sh -c ../configs/wfps2.properties 
source ./exp-wfps-2.vars

# test STP demo
curl -sk -u ${WFPS_ADMINUSER}:${WFPS_ADMINPASSWORD} -H 'accept: application/json' -H 'content-type: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X POST ${WFPS_EXTERNAL_BASE_URL}/automationservices/rest/SDSTPWP/ServiceSTP/startProcess -d '{"request": {"contextId":"ctx1", "counter": 3, "delayMillisecs": 100}}' | jq .
```

## 6. Federate/Unfederate WFPS

You can federate a WFPS instance only after installing a PFS within the same namespace.

To federate or unfederate an existing wfps instance set WFPS_FEDERATE var to true for federate or false to unfederate

### 
```
# REMEMBER: adapt the properties file to your environment
# WFPS must exists
time ./wfps-federate.sh -c ../configs/wfps1.properties

```

### 7. Spare commands
```
# get storage classes
oc get sc

# get Zen admin user name and password
oc get secrets ${WFPS_NAMESPACE} platform-auth-idp-credentials -o jsonpath='{.data.admin_username}' | base64 -d && echo
oc get secrets ${WFPS_NAMESPACE} platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d && echo

# delete all wfps
oc get wfps --no-headers | awk '{print $1}' | xargs oc delete wfps

```

# References

Installing a CP4BA Workflow Process Service production deployment [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=deployments-installing-cp4ba-workflow-process-service-production-deployment](https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=deployments-installing-cp4ba-workflow-process-service-production-deployment)

Federating IBM Business Automation Workflow on containers [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=deployment-federating-business-automation-workflow-containers](https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=deployment-federating-business-automation-workflow-containers)

TOOLS

Openshift CLI
[https://docs.openshift.com/container-platform/4.14/cli_reference/openshift_cli/getting-started-cli.html](https://docs.openshift.com/container-platform/4.14/cli_reference/openshift_cli/getting-started-cli.html)

JQ
[https://jqlang.github.io/jq](https://jqlang.github.io/jq)


For other free tools related to IBM Cloud Pak for Business Automation you can search for projects with the prefix 'cp4ba-' in my public git [https://github.com/marcoantonioni](https://github.com/marcoantonioni)

More repositories for IBM CP4BA will be made public soon.
