# cp4ba-wfps-utils

This repository contains a series of examples and tools for creating and configuring Workflow Process Service (WfPS) in IBM Cloud Pak for Business Automation deployment.

Two scenarios are described, one with non-federated servers and one with federated servers and use of Application Engine via Workplace dashboard.

For ease of demonstration, Starter type CP4BA deployments with automatically created PostgreSQL server db are used.

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


See 'Prerequisites' section before deploying WfPS servers

If you want run a WFPS environment federated using 'Process Federation Server' in container (same namespace) you must configure a PFS server, use guidance and tools from repository [https://github.com/marcoantonioni/cp4ba-process-federation-server](https://github.com/marcoantonioni/cp4ba-process-federation-server)

You may deploy non-federated WfPS into same namespace of federated WfPS server.


<b>WARNING</b>: before run any command please update configuration files with your values


## 1. Simple WfPS deploy - new instance of WfPS with a dedicated PostgreSQL database
```
#-----------------------
# WfPS deploy (non federated configuration)
time ./wfps-deploy.sh -c ./configs/wfps1.properties

#-----------------------
# WfPS deploy using trusted certificates (non federated configuration)

# create secret with remote server certificate
time ./addSecretsForTrustedCertificates.sh -c ./configs/wfps2.properties -t ./configs/trusted-certs.properties

# deploy WfPS
time ./wfps-deploy.sh -c ./configs/wfps2.properties -t ./configs/trusted-certs.properties

#-----------------------
# deploy sandbox ??????????
time ./wfps-deploy.sh -c ./configs/wfps-sandbox1.properties
time ./addSecretsForTrustedCertificates.sh -c ./configs/wfps-sandbox2.properties -t ./configs/trusted-certs.properties
time ./wfps-deploy.sh -c ./configs/wfps-sandbox2.properties -t ./configs/trusted-certs.properties

#-----------------------
# WfPS deploy (federated configuration)

time ./wfps-deploy.sh -c ./configs/wfps-federated1.properties

time ./addSecretsForTrustedCertificates.sh -c ./configs/wfps-federated2.properties -t ./configs/trusted-certs.properties

time ./wfps-deploy.sh -c ./configs/wfps-federated2.properties -t ./configs/trusted-certs.properties

time ./wfps-deploy.sh -c ./configs/wfps-bastudio-federated1.properties
```

## 2. Install application
```
#-----------------------
time ./wfps-install-application.sh -c ./configs/wfps1.properties -a ../apps/SimpleDemoWfPS.zip

time ./wfps-install-application.sh -c ./configs/wfps2.properties -a ../apps/SimpleDemoStraightThroughProcessingWfPS.zip

#-----------------------
time ./wfps-install-application.sh -c ./configs/wfps-sandbox1.properties -a ../apps/SimpleDemoWfPS.zip

time ./wfps-install-application.sh -c ./configs/wfps-sandbox2.properties -a ../apps/SimpleDemoStraightThroughProcessingWfPS.zip

#-----------------------
time ./wfps-install-application.sh -c ./configs/wfps-federated1.properties -a ../apps/SimpleDemoWfPS.zip

time ./wfps-install-application.sh -c ./configs/wfps-federated2.properties -a ../apps/SimpleDemoStraightThroughProcessingWfPS.zip

#-----------------------
time ./wfps-install-application.sh -c ./configs/wfps-bastudio-federated1.properties -a ../apps/SimpleDemoWfPS.zip

```

## 3. Configure application Team Bindings
```
# For team bindings configuration see file 'configs/team-bindings-app-1.properties'

# parameters:
# -c path to wfps configuration file
# -t path to team bindings configuration file
# -r [optional] remove actual team binding configuration 
./updateTeamBindings.sh -c ./configs/wfps1.properties -t ./configs/team-bindings-app-1.properties -r

./updateTeamBindings.sh -c ./configs/wfps-sandbox1.properties -t ./configs/team-bindings-app-1.properties -r

./updateTeamBindings.sh -c ./configs/wfps-federated1.properties -t ./configs/team-bindings-app-1.properties -r

./updateTeamBindings.sh -c ./configs/wfps-federated1.properties -t ./configs/team-bindings-app-1-devenv.properties -r

```

## Misc.

### Federate/Unfederate WfPS
```
# federate or unfederate an existing wfps instance (see WFPS_FEDERATE var)
time ./wfps-federate.sh -c ./configs/wfps-federated1.properties

time ./wfps-federate.sh -c ./configs/wfps-bastudio-federated1.properties
```


### Example of REST services invocations using curl
```
./exportWfPSEnvVars.sh -c ./configs/wfps1.properties 
source ./exp-wfps-t1.vars

curl -sk -u ${WFPS_ADMINUSER}:${WFPS_ADMINPASSWORD} -H 'accept: application/json' -H 'content-type: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X POST ${WFPS_EXTERNAL_BASE_URL}/automationservices/rest/SDWPS/SimpleDemoREST/startService -d '{"request": {"name":"Marco", "counter": 10, "flag": true}}' | jq .

curl -sk -u ${WFPS_ADMINUSER}:${WFPS_ADMINPASSWORD} -H 'accept: application/json' -H 'content-type: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X POST ${WFPS_EXTERNAL_BASE_URL}/automationservices/rest/SDWPS/SimpleDemoREST/startProcess -d '{"request": {"name":"Marco in process", "counter": 20, "flag": true}}' | jq .

```

### Spare commands
```
# get storage classes
oc get sc

# get Zen admin user name and password
oc get secrets ${WFPS_NAMESPACE} platform-auth-idp-credentials -o jsonpath='{.data.admin_username}' | base64 -d && echo
oc get secrets ${WFPS_NAMESPACE} platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d && echo

# delete all wfps
oc get wfps --no-headers | awk '{print $1}' | xargs oc delete wfps

# server's log
# export variables for wfps server
./exportWfPSEnvVars.sh -c ./configs/wfps1.properties 
source ./exp-wfps-t1.vars

oc rsh -n ${WFPS_NAMESPACE} ${WFPS_NAME}-wfps-runtime-server-0 tail -n 1000 -f /logs/application/${WFPS_NAME}-wfps-runtime-server-0/liberty-message.log


# test STP demo
USER=cp4admin
PASSWORD=XSMV5A8mc2rnyRBCeW8R
EXTERNAL_BASE_URL=https://cpd-cp4ba.apps.654892a90ae5f40017a3834c.cloud.techzone.ibm.com/bas
curl -sk -u ${USER}:${PASSWORD} -H 'accept: application/json' -H 'content-type: application/json' -X POST ${EXTERNAL_BASE_URL}/automationservices/rest/SDSTPWP/ServiceSTP/startProcess -d '{"request": {"contextId":"ctx1", "counter": 3, "delayMillisecs": 100}}' | jq .

USER=cpadmin
PASSWORD=7zn6e2DJBRrEd4kH5ZHBqt51Aai3X2Mz
curl -sk -u ${USER}:${PASSWORD} -H 'accept: application/json' -H 'content-type: application/json' -X POST ${WFPS_EXTERNAL_BASE_URL}/automationservices/rest/SDSTPWP/ServiceSTP/startProcess -d '{"request": {"contextId":"ctx1", "counter": 3, "delayMillisecs": 100}}' | jq .


```

## Prerequisites

### P1. Install CP4BA package
```
#----------------------------------------------------------------------
# install case package manager https://github.com/IBM/cloud-pak/tree/master/repo/case/ibm-cp-automation

# example for download case package setup on your laptop

cd
mkdir -p ./cp4ba-cp-mgr
cd ./cp4ba-cp-mgr

LATEST_CASE_VER=$(curl -s https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-cp-automation/index.yaml | grep latestVersion | sed 's/latestVersion: //g')
LATEST_PAK_VER=$(curl -s https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-cp-automation/index.yaml | grep latestAppVersion | sed 's/latestAppVersion: //g')
echo "Case version[${LATEST_CASE_VER}] Pak version [${LATEST_PAK_VER}]"

curl -LO https://github.com/IBM/cloud-pak/raw/master/repo/case/ibm-cp-automation/${LATEST_CASE_VER}/ibm-cp-automation-${LATEST_CASE_VER}.tgz
mkdir -p ./ibm-cp-automation-${LATEST_CASE_VER}
tar xvf ./ibm-cp-automation-${LATEST_CASE_VER}.tgz -C ibm-cp-automation-${LATEST_CASE_VER}
cd ./ibm-cp-automation-${LATEST_CASE_VER}/ibm-cp-automation/inventory/cp4aOperatorSdk/files/deploy/crs
tar xvf ./cert-k8s-*.tar
cd ./cert-kubernetes/scripts/
ls -al
CP4BA_SCRIPTS=$(pwd)
echo $CP4BA_SCRIPTS
```

### P2. Install CP4BA operators in dedicated namespace
```
#----------------------------------------------------------------------

# WARNING: Set your username
export CP4BA_AUTO_CLUSTER_USER="IAM#set-your-username-here"

# WARNING: Set your storage classes
export CP4BA_AUTO_STORAGE_CLASS_FAST_ROKS="managed-nfs-storage"
export CP4BA_AUTO_STORAGE_CLASS_BLOCK="thin-csi"

export CP4BA_AUTO_FIPS_CHECK=No
export CP4BA_AUTO_PRIVATE_CATALOG=No
export CP4BA_AUTO_PLATFORM="OCP"
export CP4BA_AUTO_ALL_NAMESPACES="No"
export CP4BA_AUTO_DEPLOYMENT_TYPE="starter"

export CP4BA_AUTO_NAMESPACE=cp4ba-demo-non-federated-wfps

oc new-project ${CP4BA_AUTO_NAMESPACE}

# create service account
cat << EOF | oc create -n ${CP4BA_AUTO_NAMESPACE} -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ibm-cp4ba-anyuid
imagePullSecrets:
- name: 'ibm-entitlement-key'
EOF

# set scc policy to service account
oc adm policy add-scc-to-user anyuid -z ibm-cp4ba-anyuid -n ${CP4BA_AUTO_NAMESPACE}

# install operators (must be in forlder $CP4BA_SCRIPTS)
./cp4a-clusteradmin-setup.sh


# wait for CP4BA operators ready

```

### P3.1 Deploy ICP4ACluster CR for NON federated WfPS example
```

#----------------------------------------------------------------------
# NON federated WfPS environment (no Applications Workplace)
# create minimal cp4ba deployment


APP_VERSION="23.0.2"
DEPL_LIC="non-production"
#DEPL_LIC="production"

# deploy CR for ICP4ACluster
cat <<EOF | oc create -n ${CP4BA_AUTO_NAMESPACE} -f -
apiVersion: icp4a.ibm.com/v1
kind: ICP4ACluster
metadata:
  name: icp4adeploy
  labels:
    app.kubernetes.io/instance: ibm-dba
    app.kubernetes.io/managed-by: ibm-dba
    app.kubernetes.io/name: ibm-dba
    release: ${APP_VERSION}
spec:
  appVersion: ${APP_VERSION}
  ibm_license: "accept"
  shared_configuration:
    show_sensitive_log: true
    sc_deployment_license: ${DEPL_LIC}
    sc_deployment_type: custom
    storage_configuration:
      sc_block_storage_classname: ${CP4BA_AUTO_STORAGE_CLASS_BLOCK}
      sc_dynamic_storage_classname: ${CP4BA_AUTO_STORAGE_CLASS_FAST_ROKS}
      sc_slow_file_storage_classname: ${CP4BA_AUTO_STORAGE_CLASS_FAST_ROKS}
      sc_medium_file_storage_classname: ${CP4BA_AUTO_STORAGE_CLASS_FAST_ROKS}
      sc_fast_file_storage_classname: ${CP4BA_AUTO_STORAGE_CLASS_FAST_ROKS}
    sc_deployment_platform: ${CP4BA_AUTO_PLATFORM}
  ## this field is required to deploy Resource Registry (RR)
  resource_registry_configuration:
    replica_size: 1
EOF


# wait for config map 'icp4adeploy-cp4ba-access-info' creation, it contains URLs and cp4admin credentials

```


### P3.2 Deploy ICP4ACluster CR for federated WfPS example
```
WARNING: Install in a different namespace, repeat step 2 using export CP4BA_AUTO_NAMESPACE=cp4ba-demo-federated-wfps

#----------------------------------------------------------------------
# federated WfPS environment (with Applications Workplace)
# create minimal cp4ba deployment

export CP4BA_AUTO_NAMESPACE=cp4ba-demo-federated-wfps


APP_VERSION="23.0.2"
DEPL_LIC="non-production"
#DEPL_LIC="production"

# deploy CR for ICP4ACluster
cat <<EOF | oc create -n ${CP4BA_AUTO_NAMESPACE} -f -
apiVersion: icp4a.ibm.com/v1
kind: ICP4ACluster
metadata:
  name: icp4adeploy-federated
  labels:
    app.kubernetes.io/instance: ibm-dba
    app.kubernetes.io/managed-by: ibm-dba
    app.kubernetes.io/name: ibm-dba
    release: ${APP_VERSION}
spec:
  appVersion: ${APP_VERSION}
  ibm_license: accept
  shared_configuration:
    enable_fips: false
    sc_deployment_type: Starter
    sc_optional_components: baw_authoring,elasticsearch
    sc_iam:
      default_admin_username: ''
    sc_drivers_url: null
    image_pull_secrets:
      - ibm-entitlement-key
    trusted_certificate_list: []
    sc_deployment_patterns: 'application,workflow-workstreams'
    sc_deployment_baw_license: ${DEPL_LIC}
    storage_configuration:
      sc_block_storage_classname: thin-csi
      sc_dynamic_storage_classname: managed-nfs-storage
      sc_fast_file_storage_classname: ''
      sc_medium_file_storage_classname: ''
      sc_slow_file_storage_classname: ''
    root_ca_secret: '{{ meta.name }}-root-ca'
    sc_content_initialization: true
    sc_deployment_license: ${DEPL_LIC}
    sc_egress_configuration:
      sc_api_namespace: null
      sc_api_port: null
      sc_dns_namespace: null
      sc_dns_port: null
      sc_restricted_internet_access: true
    sc_ingress_enable: false
    sc_image_repository: cp.icr.io
    sc_deployment_platform: OCP
    sc_deployment_fncm_license: ${DEPL_LIC}
EOF

# wait for config map 'icp4adeploy-federated-cp4ba-access-info' creation, it contains URLs and cp4admin credentials

```

### P4 Deploy local LDAP and configure IDP

Use guidance and tools from repository [https://github.com/marcoantonioni/cp4ba-idp-ldap](https://github.com/marcoantonioni/cp4ba-idp-ldap)

Now you are ready to deploy your WfPS servers, see section '1. Simple WfPS deploy...'

# References

Installing a CP4BA Workflow Process Service production deployment [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=deployments-installing-cp4ba-workflow-process-service-production-deployment](https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=deployments-installing-cp4ba-workflow-process-service-production-deployment)

Federating IBM Business Automation Workflow on containers [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=deployment-federating-business-automation-workflow-containers](https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=deployment-federating-business-automation-workflow-containers)