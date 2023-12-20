# cp4ba-wfps-utils

This repository contains a series of examples and tools for creating and configuring Workflow Process Service (WfPS) in IBM Cloud Pak for Business Automation deployment.

Two scenarios are described, one with non-federated servers and one with federated servers and use of Application Engine via Workplace dashboard.

For ease of demonstration, Starter type CP4BA deployments with automatically created PostgreSQL server db are used.


TO BE INVESTIGATED
- application_engine: https://cpd-cp4ba-application.apps.656d73e8eb178100111c14ac.cloud.techzone.ibm.com/ae-workspace/v2/applications

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

APP_VERSION="23.0.2"

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

MY_LDAP_BASE_DN="dc=vuxprod,dc=net"

APP_VERSION="23.0.2"

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
  name: icp4adeploy-federated-2
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
    - admin_secret_name: '{{ meta.name }}-workspace-aae-app-engine-admin-secret'
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


#----------------------------------------------------------------------
# SOLO FOUNDATION + LDAP
# create minimal cp4ba deployment

export CP4BA_AUTO_NAMESPACE=cp4ba-federated-wfps

#---------------------------------------------------
!!! DEPLOY LDAP - NO IDP

#--------------------------------------------------------
!!! DEPLOY POSTGRESQL per BAN

export ICN_HOST_NAME=????
export ICN_HOST_PORT=????
export ICN_DB_TS_SCHEMA=????
export ICN_DB_TS_NAME=????
export ICN_DB_NAME="ICNDB"

seguire punti:
https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=ban-creating-databases-without-running-provided-scripts
  3. Create a table space in your database.
  The FileNet Content Manager documentation provides some information on creating table spaces, on Db2, Oracle, and Microsoft SQL Server. Note that for Navigator, the sizing requirements are less than other uses, such as object stores. When you create the table space for Navigator, use "REGULAR" as the type or size.
  
  4. Create a database user.
  You can choose to use your dbadmin user, or create another database user for your Navigator database.
  For details about the kind of privileges this user needs, see Creating database accounts.

  This user that you create is included in the Business Automation Navigator secret as the navigatorDBUsername.

  5. Optionally create a schema.
  The operator can detect whether a schema exists in the database and creates one if a schema does not exist. If you want to select a schema name in advance, specify the name of your schema in the custom resource file in the icn_production_setting.icn_schema parameter. If you plan to use Task Manager, the schema name must be ICNDB.
  If you don't specify a value for the icn_production_setting.icn_schema parameter, the operator creates the following schema name:
  Oracle database: The schema is named the same as the navigatorDBUsername from the Business Automation Navigator secret.
  All other databases: The schema keeps the default name, ICNDB.




  (no volumes...?? ... https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=ban-creating-volumes-folders-deployment-kubernetes)

# utenze differenti da cpadmin devono essere in LDAP
oc delete secret -n ${CP4BA_AUTO_NAMESPACE} ibm-ban-secret
oc create secret -n ${CP4BA_AUTO_NAMESPACE} generic ibm-ban-secret \
  --from-literal=navigatorDBUsername="banadmin" \
  --from-literal=navigatorDBPassword="dem0s" \
  --from-literal=appLoginUsername="banadmin" \
  --from-literal=appLoginPassword="dem0s" \
  --from-literal=keystorePassword="changeit" \
  --from-literal=ltpaPassword="changeit"



#------------------------------------------------------------------------
oc delete secret -n ${CP4BA_AUTO_NAMESPACE} my-ldap-credentials
oc create secret -n ${CP4BA_AUTO_NAMESPACE} generic my-ldap-credentials \
  --from-literal=ldapUsername="cn=admin,dc=vuxprod,dc=net" \
  --from-literal=ldapPassword="passw0rd"

# https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=parameters-ldap-configuration
# quando molteplici LDAP o se usato attributo 'lc_ldap_id', es: 'lc_ldap_id: myldap'
# allora utenza e password devono avere formato <ldap><valore-lc-ldap-id><Username|Password>
#  --from-literal=ldapmyldapUsername="cn=admin,dc=vuxprod,dc=net" \
#  --from-literal=ldapmyldapPassword="passw0rd"

# differenze
#   lc_selected_ldap_type: "Custom" oppure "IBM Security Directory Server"
    tds:
      lc_user_filter: "(&(cn=%v)(objectclass=person))"
      lc_group_filter: "(&(cn=%v)(objectclass=groupOfNames))"
    custom:
      lc_user_filter: "(&(cn=%v)(objectclass=person))"
      lc_group_filter: "(&(cn=%v)(objectclass=groupOfNames))"



MY_LDAP_BASE_DN="dc=vuxprod,dc=net"

APP_VERSION="23.0.2"

DEPL_LIC="non-production"
#DEPL_LIC="production"

#DEPL_TYPE="starter"
DEPL_TYPE="production"
#DEPL_TYPE="custom"

# deploy CR for ICP4ACluster
cat <<EOF | oc create -f -
apiVersion: icp4a.ibm.com/v1
kind: ICP4ACluster
metadata:
  name: icp4adeploy-federated-2
  namespace: ${CP4BA_AUTO_NAMESPACE}
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

  ldap_configuration:
    lc_selected_ldap_type: "Custom"
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
    lc_ldap_recursive_search: false
    lc_enable_pagination: false
    lc_pagination_size: 4500     
    custom:
      lc_user_filter: "(&(cn=%v)(objectclass=person))"
      lc_group_filter: "(&(cn=%v)(objectclass=groupOfNames))"

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

# wait for config map 'icp4adeploy-federated-cp4ba-access-info' creation, it contains URLs and cp4admin credentials

```

### P4 Deploy local LDAP and configure IDP

Use guidance and tools from repository [https://github.com/marcoantonioni/cp4ba-idp-ldap](https://github.com/marcoantonioni/cp4ba-idp-ldap)

Now you are ready to deploy your WfPS servers, see section '1. Simple WfPS deploy...'

# References

Installing a CP4BA Workflow Process Service production deployment [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=deployments-installing-cp4ba-workflow-process-service-production-deployment](https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=deployments-installing-cp4ba-workflow-process-service-production-deployment)

Federating IBM Business Automation Workflow on containers [https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=deployment-federating-business-automation-workflow-containers](https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=deployment-federating-business-automation-workflow-containers)