# Examples for WfPS v25

## 1. WFPS Deployments

Examples for WFPS server deployments.

### 1.1 Simple WFPS deploy (dedicated PostgreSQL database)
```
# WFPS deploy (non federated configuration)
# REMEMBER: adapt the properties file to your environment

# 1. deploy WFPS (no PFS)

# WfPS 1
WFPS_CONFIG=../configs/25.0.1/wfps-wfps-demo-1.properties
TARGET_ENV_CONFIG=../../cp4ba-installations/configs25.0.1/env1-runtime-wfps.properties
time ./wfps-deploy.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG}

# WfPS 2
WFPS_CONFIG=../configs/25.0.1/wfps-wfps-demo-2.properties
TARGET_ENV_CONFIG=../../cp4ba-installations/configs25.0.1/env1-runtime-wfps.properties
time ./wfps-deploy.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG}

# WfPS 3
WFPS_CONFIG=../configs/25.0.1/wfps-wfps-demo-3.properties
TARGET_ENV_CONFIG=../../cp4ba-installations/configs25.0.1/env1-runtime-wfps.properties
time ./wfps-deploy.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG}

```

# 1. deploy WFPS (with PFS)

# WfPS 1
WFPS_CONFIG=../configs/25.0.1/wfps-wfps-demo-1.properties
TARGET_ENV_CONFIG=../../cp4ba-installations/configs25.0.1/env1-runtime-wfps-pfs.properties
time ./wfps-deploy.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG}

# WfPS 2
WFPS_CONFIG=../configs/25.0.1/wfps-wfps-demo-2.properties
TARGET_ENV_CONFIG=../../cp4ba-installations/configs25.0.1/env1-runtime-wfps-pfs.properties
time ./wfps-deploy.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG}

# WfPS 3
WFPS_CONFIG=../configs/25.0.1/wfps-wfps-demo-3.properties
TARGET_ENV_CONFIG=../../cp4ba-installations/configs25.0.1/env1-runtime-wfps-pfs.properties
time ./wfps-deploy.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG}

```

Examples for PFS federated WFPS server deployments.
```
WFPS_CONFIG=../configs/25.0.1/wfps-wfps-demo-pfs-1.properties
TARGET_ENV_CONFIG=../../cp4ba-installations/configs25.0.1/env1-runtime-wfps-pfs.properties
time ./wfps-deploy.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG}

WFPS_CONFIG=../configs/25.0.1/wfps-wfps-demo-pfs-2.properties
TARGET_ENV_CONFIG=../../cp4ba-installations/configs25.0.1/env1-runtime-wfps-pfs.properties
time ./wfps-deploy.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG}

WFPS_CONFIG=../configs/25.0.1/wfps-wfps-demo-pfs-3.properties
TARGET_ENV_CONFIG=../../cp4ba-installations/configs25.0.1/env1-runtime-wfps-pfs.properties
time ./wfps-deploy.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG}
```

### 1.2 Simple WFPS deploy (dedicated PostgreSQL database)
```

### [DEPRECATED] 1.2 Simple WFPS deploy with trusted certificates (dedicated PostgreSQL database built by operator)
```
# WFPS deploy using trusted certificates (non federated configuration)
# REMEMBER: adapt the properties file to your environment

# 1. create secret with remote server certificate
time ./wfps-add-secrets-trusted-certs.sh -c ${WFPS_CONFIG} -t ../configs/trusted-certs.properties

# 2. deploy WFPS and add trusted certificates list
time ./wfps-deploy.sh -c ${WFPS_CONFIG} -t ../configs/trusted-certs.properties
```

### 1.3 show WFPS infos

```
WFPS_CONFIG=../configs/25.0.1/wfps-wfps-demo-1.properties
TARGET_ENV_CONFIG=../../cp4ba-installations/configs25.0.1/env1-runtime-wfps-pfs.properties
./wfps-export-env-vars-to-file.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG}
```

### 1.4 show WFPS server logs

```
WFPS_CONFIG=../configs/25.0.1/wfps-wfps-demo-1.properties
TARGET_ENV_CONFIG=../../cp4ba-installations/configs25.0.1/env1-runtime-wfps-pfs.properties
./wfps-export-env-vars-to-file.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG}

# source using generated vars file (adapt the file name to your wfps name)
source ${TARGET_ENV_CONFIG}
source ${WFPS_CONFIG}
source ../output/exp-${WFPS_NAME}.vars

oc rsh -n ${WFPS_NAMESPACE} ${WFPS_NAME}-wfps-runtime-server-0 tail -n 1000 -f /logs/application/${WFPS_NAME}-wfps-runtime-server-0/liberty-message.log
```

## 2. Application deployment

Example for installing applications.

### 2.1 Deploy application
```
WFPS_CONFIG=../configs/25.0.1/wfps-wfps-demo-1.properties
TARGET_ENV_CONFIG=../../cp4ba-installations/configs25.0.1/env1-runtime-wfps-pfs.properties

# install first application using WFPS runtime 
time ./wfps-install-application.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG} -a ../apps/SimpleDemoWfPS1.zip

# install second application using WFPS runtime 
time ./wfps-install-application.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG} -a ../apps/SimpleDemoWfPS2.zip

# install third application using WFPS runtime 
time ./wfps-install-application.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG} -a ../apps/SimpleDemoStraightThroughProcessingWfPS.zip
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

time ./wfps-update-team-bindings.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG} -t ../configs/team-bindings-app-1.properties -r
```

## 4.1 Update application

To activate|deactivate or make as 'default' a snapshot
```
WFPS_CONFIG=../configs/25.0.1/wfps-wfps-demo-1.properties
TARGET_ENV_CONFIG=../../cp4ba-installations/configs25.0.1/env1-runtime-wfps-pfs.properties

# deactivate app, dont force (may result in error if unique snapshot)
time ./wfps-update-application.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG} -a SDWPSB1 -b 1.0 -s deactivate

# deactivate demo app, force process instances suspension
time ./wfps-update-application.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG} -a SDWPSB1 -b 1.0 -s deactivate -f

# activate app
time ./wfps-update-application.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG} -a SDWPSB1 -b 1.0 -s activate
```

## 4.2 Remove snapshot

Prerequisite: The snapshot must be deactivated
```
WFPS_CONFIG=../configs/25.0.1/wfps-wfps-demo-1.properties
TARGET_ENV_CONFIG=../../cp4ba-installations/configs25.0.1/env1-runtime-wfps-pfs.properties

time ./wfps-update-application.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG} -a SDWPSB1 -b 1.0 -s deactivate -f

# remove app, no force (may result in error if unique snapshot)
time ./wfps-remove-application.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG} -a SDWPSB1 -b 1.0

# remove app, force
time ./wfps-remove-application.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG} -a SDWPSB1 -b 1.0 -f

```

## 5. Examples of REST services invocations using curl

Below are some examples for invoking REST services exposed by the demo applications deployed in WFPS.

The script 'wfps-export-env-vars-to-file.sh' exports the environment variables necessary to interact via 'cUrl' with REST services into a support file.

### 5.1 Interact with services from 'SimpleDemoWFPS' application

Login in browser to '<b>/Workplace</b>' as a user defined in TeamBindings role to interact with tasks.
To administer the WfPS runtime login in browser to '<b>/ProcessAdmin</b>' as admin user defined in configuration variable '<i>WFPS_ADMINUSER</i>'.


```
# generate and source env vars
WFPS_CONFIG=../configs/25.0.1/wfps-wfps-demo-1.properties
TARGET_ENV_CONFIG=../../cp4ba-installations/configs25.0.1/env1-runtime-wfps-pfs.properties
./wfps-export-env-vars-to-file.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG}

source ${TARGET_ENV_CONFIG} 2> /dev/null 1> /dev/null
source ${WFPS_CONFIG} 2> /dev/null 1> /dev/null
source ../output/exp-${WFPS_NAME}.vars

# call a service
_APP_ACRONYM="SDWPSB1"
curl -sk -u ${WFPS_ADMINUSER}:${WFPS_ADMINPASSWORD} -H 'accept: application/json' -H 'content-type: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X POST ${WFPS_EXTERNAL_BASE_URL}/automationservices/rest/${_APP_ACRONYM}/SimpleDemoWfPS1REST/startService -d '{"request": {"name":"Marco", "counter": 10, "flag": true}}' | jq .

# call a service that start a new process instance
curl -sk -u ${WFPS_ADMINUSER}:${WFPS_ADMINPASSWORD} -H 'accept: application/json' -H 'content-type: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X POST ${WFPS_EXTERNAL_BASE_URL}/automationservices/rest/${_APP_ACRONYM}/SimpleDemoWfPS1REST/startProcess -d '{"request": {"name":"Marco in process", "counter": 20, "flag": true}}' | jq .

```
### 5.2 Interact with services from 'SimpleDemoStraightThroughProcessingWfPS' application
```
# generate and source env vars
WFPS_CONFIG=../configs/25.0.1/wfps-wfps-demo-1.properties
# WFPS_CONFIG=../configs/25.0.1/wfps-wfps-demo-2.properties
TARGET_ENV_CONFIG=../../cp4ba-installations/configs25.0.1/env1-runtime-wfps-pfs.properties
./wfps-export-env-vars-to-file.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG}

source ${TARGET_ENV_CONFIG} 2> /dev/null 1> /dev/null
source ${WFPS_CONFIG} 2> /dev/null 1> /dev/null
source ../output/exp-${WFPS_NAME}.vars

# test STP demo
_APP_ACRONYM="SDSTPWP"

curl -sk -u ${WFPS_ADMINUSER}:${WFPS_ADMINPASSWORD} -H 'accept: application/json' -H 'content-type: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X POST ${WFPS_EXTERNAL_BASE_URL}/automationservices/rest/${_APP_ACRONYM}/ServiceSTP/startProcess -d '{"request": {"contextId":"ctx1", "counter": 3, "delayMillisecs": 100}}' | jq .

# NOTA: process instance will fail if application 'SimpleDemoServicesWfPS' is not deployed.

WFPS_CONFIG=../configs/25.0.1/wfps-wfps-demo-2.properties
TARGET_ENV_CONFIG=../../cp4ba-installations/configs25.0.1/env1-runtime-wfps-pfs.properties

# install first application using WFPS runtime 
time ./wfps-install-application.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG} -a ../apps/SimpleDemoServicesWfPS.zip

```

## 6. Federate/Unfederate WFPS

You can federate a WFPS instance only after installing a PFS within the same namespace.

To federate or unfederate an existing wfps instance set WFPS_FEDERATE var to true for federate or false to unfederate

### 
```
# REMEMBER: adapt the properties file to your environment
# WFPS must exists
WFPS_CONFIG=../configs/25.0.1/wfps-wfps-demo-1.properties
TARGET_ENV_CONFIG=../../cp4ba-installations/configs25.0.1/env1-runtime-wfps-pfs.properties
time ./wfps-federate.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG}

```

### 7. Spare commands
```
# get storage classes
oc get sc

# get Zen admin user name and password
oc get secrets -n ${WFPS_NAMESPACE} platform-auth-idp-credentials -o jsonpath='{.data.admin_username}' | base64 -d && echo
oc get secrets -n ${WFPS_NAMESPACE} platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d && echo

# delete all wfps
oc get wfps -n ${WFPS_NAMESPACE} --no-headers | awk '{print $1}' | xargs oc delete wfps -n ${WFPS_NAMESPACE}

```