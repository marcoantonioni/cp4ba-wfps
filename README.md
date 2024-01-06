# cp4ba-wfps


ToBeDone
```
- full deployments
- curl services
- prerequisites section
```


This repository contains a series of examples and tools for creating and configuring Workflow Process Service (WfPS) in IBM Cloud Pak for Business Automation deployment.

Two scenarios are described, one with non-federated servers and one with federated servers.

For both scenarios we will use a 'starter' type installation.

The second scenario is preparatory to a more complex configuration which requires the presence of a federated BAW runtime instance as well.

The BAW in its '/ProcessPortal' dashboard will offer the applications/tasks running on the other federated WFPSs.

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

All examples make use of dynamic storage, the presence of a storage class for dynamic volume allocation is required.

The tools 'oc' and 'jq' are required.

The 'openssl' tool is required only for the integration scenario with external services protected by TLS transports.

All examples and scripts are only available for Linux boxes.

<b>WARNING</b>: before run any command please update configuration files with your values

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

## 1. WfPS Deployments

Examples for WfPS server deployments.

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

## 4. Update application

```
TO-BE
time ./wfps-update-application.sh
```

## 4. Federate/Unfederate WfPS

To federate or unfederate an existing wfps instance set WFPS_FEDERATE var to true for federate or false to unfederate

### 
```
# REMEMBER: adapt the properties file to your environment
# WfPS must exists
time ./wfps-federate.sh -c ../configs/wfps1.properties

```

## 5. Examples of REST services invocations using curl

Below are some examples for invoking REST services exposed by the demo applications deployed in WfPS.

The script 'wfps-export-env-vars-to-file.sh' exports the environment variables necessary to interact via 'cUrl' with REST services into a support file.

### 5.1 Interact with services from 'SimpleDemoREST' application
```
#------------------------------------------
# generate and source env vars
./wfps-export-env-vars-to-file.sh -c ../configs/wfps1.properties 
source ./exp-wfps-1.vars

# call a service
curl -sk -u ${WFPS_ADMINUSER}:${WFPS_ADMINPASSWORD} -H 'accept: application/json' -H 'content-type: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X POST ${WFPS_EXTERNAL_BASE_URL}/automationservices/rest/SDWPS/SimpleDemoREST/startService -d '{"request": {"name":"Marco", "counter": 10, "flag": true}}' | jq .

# call a service that start a new porcess instance
curl -sk -u ${WFPS_ADMINUSER}:${WFPS_ADMINPASSWORD} -H 'accept: application/json' -H 'content-type: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X POST ${WFPS_EXTERNAL_BASE_URL}/automationservices/rest/SDWPS/SimpleDemoREST/startProcess -d '{"request": {"name":"Marco in process", "counter": 20, "flag": true}}' | jq .

```
### 5.2 Interact with services from 'SimpleDemoREST' application
```
#------------------------------------------
# generate and source env vars
./wfps-export-env-vars-to-file.sh -c ../configs/wfps2.properties 
source ./exp-wfps-2.vars

# test STP demo
curl -sk -u ${WFPS_ADMINUSER}:${WFPS_ADMINPASSWORD} -H 'accept: application/json' -H 'content-type: application/json' -H 'BPMCSRFToken: '${WFPS_CSRF_TOKEN} -X POST ${WFPS_EXTERNAL_BASE_URL}/automationservices/rest/SDSTPWP/ServiceSTP/startProcess -d '{"request": {"contextId":"ctx1", "counter": 3, "delayMillisecs": 100}}' | jq .
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
./wfps-export-env-vars-to-file.sh -c ../configs/wfps1.properties 
source ./exp-wfps-t1.vars

oc rsh -n ${WFPS_NAMESPACE} ${WFPS_NAME}-wfps-runtime-server-0 tail -n 1000 -f /logs/application/${WFPS_NAME}-wfps-runtime-server-0/liberty-message.log
```

TBD

Move to installations repo ...

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

#export CP4BA_AUTO_DEPLOYMENT_TYPE="starter"
export CP4BA_AUTO_DEPLOYMENT_TYPE="production"

# CHANGE IT !!!
#export CP4BA_AUTO_NAMESPACE=cp4ba-non-federated-wfps
export CP4BA_AUTO_NAMESPACE=cp4ba-federated-wfps

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

export CP4BA_AUTO_NAMESPACE=cp4ba-non-federated-wfps

APP_VERSION="23.2.0"

#DEPL_LIC="non-production"
DEPL_LIC="production"

#DEPL_TYPE="starter"
DEPL_TYPE="production"

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
    sc_deployment_type: ${DEPL_TYPE}
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

        export CP4BA_AUTO_NAMESPACE=cp4ba-federated-wfps


        oc delete secret -n ${CP4BA_AUTO_NAMESPACE} my-ldap-credentials
        oc create secret -n ${CP4BA_AUTO_NAMESPACE} generic my-ldap-credentials \
          --from-literal=ldapUsername="cn=admin,dc=vuxprod,dc=net" \
          --from-literal=ldapPassword="passw0rd"

        oc delete secret -n ${CP4BA_AUTO_NAMESPACE} my-app-engine-credentials
        oc create secret -n ${CP4BA_AUTO_NAMESPACE} generic my-app-engine-credentials \
          --from-literal=AE_DATABASE_USER="cpadmin" \
          --from-literal=AE_DATABASE_PWD="passw0rd"

        MY_LDAP_BASE_DN="dc=vuxprod,dc=net"

        APP_VERSION="23.2.0"

        DEPL_LIC="non-production"
        #DEPL_LIC="production"

        #DEPL_TYPE="starter"
        DEPL_TYPE="production"
        #DEPL_TYPE="custom"


        # TBV application_engine_configuration section
        # ??? credenziali db in icp4adeploy-federated-workspace-aae-app-engine-admin-secret (AE_DATABASE_USER, AE_DATABASE_PWD)

        # deploy CR for ICP4ACluster
        cat <<EOF | oc create -f -
        apiVersion: icp4a.ibm.com/v1
        kind: ICP4ACluster
        metadata:
          name: icp4adeploy-federated
          namespace: ${CP4BA_AUTO_NAMESPACE}
          labels:
            app.kubernetes.io/instance: ibm-dba
            app.kubernetes.io/managed-by: ibm-dba
            app.kubernetes.io/name: ibm-dba
            release: ${APP_VERSION}
        spec:
          appVersion: ${APP_VERSION}
          ibm_license: accept

          application_engine_configuration:
            - admin_secret_name: my-app-engine-credentials
              admin_user: cpadmin
              name: workspace
              session:
                use_external_store: false

          shared_configuration:
            enable_fips: false
            sc_deployment_type: ${DEPL_TYPE}
            sc_optional_components: elasticsearch
            sc_iam:
              default_admin_username: ''
            sc_drivers_url: null
            image_pull_secrets:
              - ibm-entitlement-key
            trusted_certificate_list: []
            sc_deployment_patterns: 'application,workflow'
            sc_deployment_baw_license: ${DEPL_LIC}
            storage_configuration:
              sc_block_storage_classname: ${CP4BA_AUTO_STORAGE_CLASS_BLOCK}
              sc_dynamic_storage_classname: ${CP4BA_AUTO_STORAGE_CLASS_FAST_ROKS}
              sc_fast_file_storage_classname: ${CP4BA_AUTO_STORAGE_CLASS_FAST_ROKS}
              sc_medium_file_storage_classname: ${CP4BA_AUTO_STORAGE_CLASS_FAST_ROKS}
              sc_slow_file_storage_classname: ${CP4BA_AUTO_STORAGE_CLASS_FAST_ROKS}
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

          ldap_configuration:
            lc_selected_ldap_type: "IBM Security Directory Server"
            lc_ldap_server: "vuxprod-ldap.${CP4BA_AUTO_NAMESPACE}.svc.cluster.local"
            lc_ldap_port: "389"
            lc_bind_secret: my-ldap-credentials
            lc_ldap_base_dn: "${MY_LDAP_BASE_DN}"
            lc_ldap_ssl_enabled: false
            lc_ldap_ssl_secret_name: ""
            lc_ldap_user_name_attribute: "*:cn"
            lc_ldap_user_display_name_attr: "cn"
            lc_ldap_group_base_dn: "${MY_LDAP_BASE_DN}"
            lc_ldap_group_name_attribute: "*:cn"
            lc_ldap_group_display_name_attr: "cn"
            lc_ldap_group_membership_search_filter: "(&(cn=%v)(objectclass=groupOfNames))"
            lc_ldap_group_member_id_map: "memberof:member"
            tds:
              lc_user_filter: "(&(cn=%v)(objectclass=person))"
              lc_group_filter: "(&(cn=%v)(objectclass=groupOfNames))"

        EOF

# wait for config map 'icp4adeploy-federated-cp4ba-access-info' creation, it contains URLs and cp4admin credentials


#***************************************
# SOLO FOUNDATION + LDAP
# create minimal cp4ba deployment
#***************************************

export CP4BA_AUTO_NAMESPACE=cp4ba-federated-wfps

#------------------------------------------------------------------------
# LDAP
#------------------------------------------------------------------------

# DEPLOY LDAP - NO IDP

cd /home/marco/wfps/cp4ba-idp-ldap
./scripts/add-ldap.sh -p ../configs/_cfg-production-ldap-domain.properties

# dopo per utilizzo certificati
./scripts/add-phpadmin.sh -p ../configs/_cfg-production-ldap-domain.properties -s common-web-ui-cert -w common-web-ui-cert -n ${CP4BA_AUTO_NAMESPACE}



#------------------------------------------------------------------------
# Deploy POSTGRESQL for BAN and AE
#------------------------------------------------------------------------

See: README-POSTGRES-BAN.md
See: README-POSTGRES-AE.md

#------------------------------------------------------------------------
# Deploy ICP4ACluster
#------------------------------------------------------------------------

# Dettagli LDAP
#
# https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=parameters-ldap-configuration
# quando molteplici LDAP o se usato attributo 'lc_ldap_id', es: 'lc_ldap_id: myldap'
# allora utenza e password devono avere formato <ldap><valore-lc-ldap-id><Username|Password>
#  --from-literal=ldapmyldapUsername="cn=admin,dc=vuxprod,dc=net" \
#  --from-literal=ldapmyldapPassword="passw0rd"
# differenze
#   lc_selected_ldap_type: "Custom" oppure "IBM Security Directory Server"
#   tds:
#     lc_user_filter: "(&(cn=%v)(objectclass=person))"
#     lc_group_filter: "(&(cn=%v)(objectclass=groupOfNames))"
#   custom:
#     lc_user_filter: "(&(cn=%v)(objectclass=person))"
#     lc_group_filter: "(&(cn=%v)(objectclass=groupOfNames))"

# >>>> README-POSTGRES-BAN.md
ICN_CR_NAME=my-postgres-ban
ICN_DB_OWNER=postgres

ICN_HOST_NAME="${ICN_CR_NAME}-rw.${CP4BA_AUTO_NAMESPACE}.svc.cluster.local"
ICN_HOST_PORT=5432
ICN_DB_SCHEMA="ICNDB"
ICN_DB_TS_NAME="ICNDB"
ICN_DB_NAME="ICNDB"
# >>>>

# >>>> README-POSTGRES-AE.md
AE_CR_NAME=my-postgres-ae
AE_DB_OWNER=postgres

AE_HOST_NAME="${AE_CR_NAME}-rw.${CP4BA_AUTO_NAMESPACE}.svc.cluster.local"
AE_HOST_PORT=5432
AE_DB_SCHEMA="AEDB"
AE_DB_TS_NAME="AEDB"
AE_DB_NAME="AEDB"
# >>>>

AE_SECRET=my-app-engine-credentials

LDAP_SECRET=my-ldap-credentials
oc delete secret -n ${CP4BA_AUTO_NAMESPACE} ${LDAP_SECRET}
oc create secret -n ${CP4BA_AUTO_NAMESPACE} generic ${LDAP_SECRET} \
  --from-literal=ldapUsername="cn=admin,dc=vuxprod,dc=net" \
  --from-literal=ldapPassword="passw0rd"

MY_LDAP_BASE_DN="dc=vuxprod,dc=net"

APP_VERSION="23.2.0"

DEPL_LIC="non-production"
#DEPL_LIC="production"

#DEPL_TYPE="starter"
DEPL_TYPE="production"
#DEPL_TYPE="custom"

LC_SELECTED_LDAP_TYPE="IBM Security Directory Server"
LC_SELECTED_LDAP_EXT_TAG="tds"
#LC_SELECTED_LDAP_TYPE="Custom"
#LC_SELECTED_LDAP_EXT_TAG="custom"

# https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=parameters-application-engine

# deploy CR for ICP4ACluster
cat <<EOF | oc create -f -
apiVersion: icp4a.ibm.com/v1
kind: ICP4ACluster
metadata:
  name: icp4adeploy-federated
  namespace: ${CP4BA_AUTO_NAMESPACE}
  labels:
    app.kubernetes.io/instance: ibm-dba
    app.kubernetes.io/managed-by: ibm-dba
    app.kubernetes.io/name: ibm-dba
    release: ${APP_VERSION}
spec:
  appVersion: ${APP_VERSION}
  ibm_license: accept
  application_engine_configuration:
    - name: workspace
      admin_secret_name: "${AE_SECRET}"
      admin_user: "cpadmin"
      use_custom_jdbc_drivers: false
      session:
        use_external_store: false
      database:
        host: "${AE_HOST_NAME}"
        name: "${AE_DB_NAME}"
        port: "${AE_HOST_PORT}"      
        type: postgresql
        enable_ssl: false
  shared_configuration:
    enable_fips: false
    sc_deployment_type: ${DEPL_TYPE}
    sc_optional_components: ''
    sc_iam:
      default_admin_username: 'cpadmin'
    sc_drivers_url: null
    image_pull_secrets:
      - ibm-entitlement-key
    trusted_certificate_list: []
    sc_deployment_patterns: 'foundation'
    sc_deployment_baw_license: ${DEPL_LIC}
    storage_configuration:
      sc_block_storage_classname: ${CP4BA_AUTO_STORAGE_CLASS_BLOCK}
      sc_dynamic_storage_classname: ${CP4BA_AUTO_STORAGE_CLASS_FAST_ROKS}
      sc_fast_file_storage_classname: ${CP4BA_AUTO_STORAGE_CLASS_FAST_ROKS}
      sc_medium_file_storage_classname: ${CP4BA_AUTO_STORAGE_CLASS_FAST_ROKS}
      sc_slow_file_storage_classname: ${CP4BA_AUTO_STORAGE_CLASS_FAST_ROKS}
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

  ldap_configuration:
    lc_selected_ldap_type: "${LC_SELECTED_LDAP_TYPE}"
    lc_ldap_server: "vuxprod-ldap.${CP4BA_AUTO_NAMESPACE}.svc.cluster.local"
    lc_ldap_port: "389"
    lc_bind_secret: ${LDAP_SECRET}
    lc_ldap_base_dn: "${MY_LDAP_BASE_DN}"
    lc_ldap_ssl_enabled: false
    lc_ldap_ssl_secret_name: ""
    lc_ldap_user_name_attribute: "*:cn"
    lc_ldap_user_display_name_attr: "cn"
    lc_ldap_group_base_dn: "${MY_LDAP_BASE_DN}"
    lc_ldap_group_name_attribute: "*:cn"
    lc_ldap_group_display_name_attr: "cn"
    lc_ldap_group_membership_search_filter: "(&(cn=%v)(objectclass=groupOfNames))"
    lc_ldap_group_member_id_map: "memberof:member"
    lc_ldap_recursive_search: false
    lc_enable_pagination: false
    lc_pagination_size: 4500     
    ${LC_SELECTED_LDAP_EXT_TAG}:
      lc_user_filter: "(&(cn=%v)(objectclass=person))"
      lc_group_filter: "(&(cn=%v)(objectclass=groupOfNames))"

  datasource_configuration:
    dc_icn_datasource:
      dc_database_type: "postgresql"
      dc_common_icn_datasource_name: "ECMClientDS"
      database_servername: "${ICN_HOST_NAME}"
      database_port: "${ICN_HOST_PORT}"
      database_name: "${ICN_DB_NAME}"
      database_ssl_secret_name: ""

  navigator_configuration:
    icn_production_setting:
      icn_jndids_name: ECMClientDS
      icn_schema: "${ICN_DB_SCHEMA}"
      icn_table_space: "${ICN_DB_TS_NAME}"

EOF

# !!! attendere presenza secrets

oc get secret -n ${CP4BA_AUTO_NAMESPACE} ${ICN_CR_NAME}-app
oc get secret -n ${CP4BA_AUTO_NAMESPACE} ${AE_CR_NAME}-app

_USER_NAME=$(oc get secret -n ${CP4BA_AUTO_NAMESPACE} ${ICN_CR_NAME}-app -o jsonpath='{.data.username}' | base64 -d)
_USER_PASSWORD=$(oc get secret -n ${CP4BA_AUTO_NAMESPACE} ${ICN_CR_NAME}-app -o jsonpath='{.data.password}' | base64 -d)
oc delete secret -n ${CP4BA_AUTO_NAMESPACE} ibm-ban-secret
oc create secret -n ${CP4BA_AUTO_NAMESPACE} generic ibm-ban-secret \
  --from-literal=navigatorDBUsername="${_USER_NAME}" \
  --from-literal=navigatorDBPassword="${_USER_PASSWORD}" \
  --from-literal=appLoginUsername="vuxuser10" \
  --from-literal=appLoginPassword="dem0s" \
  --from-literal=keystorePassword="changeit" \
  --from-literal=ltpaPassword="changeit"

_USER_NAME=$(oc get secret -n ${CP4BA_AUTO_NAMESPACE} ${AE_CR_NAME}-app -o jsonpath='{.data.username}' | base64 -d)
_USER_PASSWORD=$(oc get secret -n ${CP4BA_AUTO_NAMESPACE} ${AE_CR_NAME}-app -o jsonpath='{.data.password}' | base64 -d)
oc delete secret -n ${CP4BA_AUTO_NAMESPACE} ${AE_SECRET}
oc create secret -n ${CP4BA_AUTO_NAMESPACE} generic ${AE_SECRET} \
  --from-literal=AE_DATABASE_USER="${_USER_NAME}" \
  --from-literal=AE_DATABASE_PWD="${_USER_PASSWORD}"

oc get secret -n ${CP4BA_AUTO_NAMESPACE} ibm-ban-secret -o jsonpath='{.data.navigatorDBUsername}' | base64 -d
oc get secret -n ${CP4BA_AUTO_NAMESPACE} ${AE_SECRET} -o jsonpath='{.data.AE_DATABASE_USER}' | base64 -d


# follow operator log
oc logs -f -n ${CP4BA_AUTO_NAMESPACE} $(oc get pods -n ${CP4BA_AUTO_NAMESPACE} | grep ibm-cp4a-operator- | awk '{print $1}')

# wait for config map 'icp4adeploy-federated-cp4ba-access-info' creation, it contains URLs and cp4admin credentials

```

### [OPTIONAL] P4 Deploy additional local LDAP and configure IDP

Use guidance and tools from repository [https://github.com/marcoantonioni/cp4ba-idp-ldap](https://github.com/marcoantonioni/cp4ba-idp-ldap)

Now you are ready to deploy your WfPS servers, see section '1. Simple WfPS deploy...'

# References

Installing a CP4BA Workflow Process Service production deployment [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=deployments-installing-cp4ba-workflow-process-service-production-deployment](https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=deployments-installing-cp4ba-workflow-process-service-production-deployment)

Federating IBM Business Automation Workflow on containers [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=deployment-federating-business-automation-workflow-containers](https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=deployment-federating-business-automation-workflow-containers)