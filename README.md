# cp4ba-wfps

This repository contains a series of examples and tools for creating and configuring Workflow Process Service (WfPS) in IBM Cloud Pak for Business Automation deployment.

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


See '[Prerequisites](#Prerequisites)' section before deploying WfPS servers.

If you want run a WFPS instance in federated environment using 'Process Federation Server' in container (same namespace) you must configure a <b>PFS</b> deployment; use guidance and tools from repository [https://github.com/marcoantonioni/cp4ba-process-federation-server](https://github.com/marcoantonioni/cp4ba-process-federation-server)

You may deploy non-federated WfPS into same namespace of federated WfPS server.

All examples make use of dynamic storage, the presence of a storage class for dynamic volume allocation is required.

The tools '<i>oc</i>' and '<i>jq</i>' are required.

The '<i>openssl</i>' tool is required only for the integration scenario with external services protected by TLS transports.

All examples and scripts are only available for Linux boxes with <i>bash</i> shell.

<b>WARNING</b>: before run any command please update configuration files with your values.

## Description of configuration files and variables

WfpS configuration file variables
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
```

Trusted certificates configuration file variables
```
TCERT_ENDPOINT_URL_1=<hostname-and-port-of-target-service> # eg: cpd-cp4ba.apps.1234567890.cloud.techzone.ibm.com:443
TCERT_SECRET_NAME_1=<secret-name> # any name k8s compatible

# add as you like with sequential number as suffix
TCERT_ENDPOINT_URL_2=
TCERT_SECRET_NAME_2=
```

## Demo application

../apps/SimpleDemoWfPS.zip

TO-BE-CHANGED
../apps/SimpleDemoStraightThroughProcessingWfPS.zip

TO-BE
../apps/SimpleExternalService.zip

## Prerequisites

To continue with the deployment examples, the following prerequisites must be met:

- The destination namespace must contain a Foundation deployment.

## 1. WfPS Deployments

Examples for WfPS server deployments.

Login in browser to '<b>/ProcessAdmin</b>' as admin user defined in configuration variable '<i>WFPS_ADMINUSER</i>'.


### 1.1 Simple WfPS deploy (dedicated PostgreSQL database built by operator)
```
#-------------------------------------------
# WfPS deploy (non federated configuration)
#-------------------------------------------
# REMEMBER: adapt the properties file to your environment

# 1. deploy WfPS
time ./wfps-deploy.sh -c ../configs/wfps1.properties
```

### 1.2 Simple WfPS deploy with trusted certificates (dedicated PostgreSQL database built by operator)
```
#-------------------------------------------
# WfPS deploy using trusted certificates (non federated configuration)
#-------------------------------------------
# REMEMBER: adapt the properties file to your environment

# 1. create secret with remote server certificate
time ./wfps-add-secrets-trusted-certs.sh -c ../configs/wfps2.properties -t ../configs/trusted-certs.properties

# 2. deploy WfPS and add trusted certificates list
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
#-----------------------
# install application using WfPS runtime described in 'wfps1.properties'
time ./wfps-install-application.sh -c ../configs/wfps1.properties -a ../apps/SimpleDemoWfPS.zip

# install application using WfPS runtime described in 'wfps3.properties'
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

## 5. Federate/Unfederate WfPS

To federate or unfederate an existing wfps instance set WFPS_FEDERATE var to true for federate or false to unfederate

### 
```
# REMEMBER: adapt the properties file to your environment
# WfPS must exists
time ./wfps-federate.sh -c ../configs/wfps1.properties

```

## 6. Examples of REST services invocations using curl

Below are some examples for invoking REST services exposed by the demo applications deployed in WfPS.

The script 'wfps-export-env-vars-to-file.sh' exports the environment variables necessary to interact via 'cUrl' with REST services into a support file.

### 6.1 Interact with services from 'SimpleDemoWfPS' application

Login in browser to '<b>/Workplace</b>' as a user defined in TeamBindings role to interact with tasks.

```
#------------------------------------------
# generate and source env vars
./wfps-export-env-vars-to-file.sh -c ../configs/wfps1.properties 
source ./exp-wfps-1.vars

# call a service
curl -sk -u ${WFPS_ADMINUSER}:${WFPS_ADMINPASSWORD} -H 'accept: application/json' -H 'content-type: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X POST ${WFPS_EXTERNAL_BASE_URL}/automationservices/rest/SDWPS/SimpleDemoREST/startService -d '{"request": {"name":"Marco", "counter": 10, "flag": true}}' | jq .

# call a service that start a new process instance
curl -sk -u ${WFPS_ADMINUSER}:${WFPS_ADMINPASSWORD} -H 'accept: application/json' -H 'content-type: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X POST ${WFPS_EXTERNAL_BASE_URL}/automationservices/rest/SDWPS/SimpleDemoREST/startProcess -d '{"request": {"name":"Marco in process", "counter": 20, "flag": true}}' | jq .

```
### 6.2 Interact with services from 'SimpleDemoStraightThroughProcessingWfPS' application
```
#------------------------------------------
# generate and source env vars
./wfps-export-env-vars-to-file.sh -c ../configs/wfps2.properties 
source ./exp-wfps-2.vars

# test STP demo
curl -sk -u ${WFPS_ADMINUSER}:${WFPS_ADMINPASSWORD} -H 'accept: application/json' -H 'content-type: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X POST ${WFPS_EXTERNAL_BASE_URL}/automationservices/rest/SDSTPWP/ServiceSTP/startProcess -d '{"request": {"contextId":"ctx1", "counter": 3, "delayMillisecs": 100}}' | jq .
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