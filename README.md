# cp4ba-wfps-utils

TTD
- config jdbc datasource
- test kafka services

## Simple Deploy - new instance of WfPS with a dedicated PostgreSQL database
```
# simple deploy
time ./wfps-deploy.sh -c ./configs/wfps1.properties

# deploy using trusted certificates
time ./addSecretsForTrustedCertificates -c ./configs/wfps1.properties -t ./configs/trusted-certs.properties
time ./wfps-deploy.sh -c ./configs/wfps1.properties -t ./configs/trusted-certs.properties

# deploy
time ./wfps-deploy.sh -c ./configs/wfps2.properties
time ./wfps-deploy.sh -c ./configs/wfps3.properties
time ./wfps-deploy.sh -c ./configs/wfps4.properties
time ./wfps-deploy.sh -c ./configs/wfps5.properties
time ./wfps-deploy.sh -c ./configs/wfps6.properties
time ./wfps-deploy.sh -c ./configs/wfps7.properties
time ./wfps-deploy.sh -c ./configs/wfps8.properties
time ./wfps-deploy.sh -c ./configs/wfps9.properties
time ./wfps-deploy.sh -c ./configs/wfps10.properties

```

## Install application
```
time ./wfps-install-application.sh -c ./configs/wfps1.properties -a ../apps/SimpleDemoWfPS.zip

time ./wfps-install-application.sh -c ./configs/wfps2.properties -a ../apps/SimpleDemoStraightThroughProcessingWfPS.zip
```

## Example of REST services invocations using curl
```
# 
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

```
source ./configs/wfps1.properties

# set target namespace
export CP4BA_AUTO_NAMESPACE=${WFPS_NAMESPACE}
echo "WfPS target namespace: "${CP4BA_AUTO_NAMESPACE}

export CP4BA_AUTO_PLATFORM="OCP"
export CP4BA_AUTO_ALL_NAMESPACES="No"
export CP4BA_AUTO_CLUSTER_USER="IAM#marco_antonioni@it.ibm.com"
export CP4BA_AUTO_STORAGE_CLASS_FAST_ROKS="managed-nfs-storage"
export CP4BA_AUTO_STORAGE_CLASS_BLOCK=thin-csi
export CP4BA_AUTO_DEPLOYMENT_TYPE="starter"

oc new-project ${CP4BA_AUTO_NAMESPACE}

cat << EOF | oc create -n ${CP4BA_AUTO_NAMESPACE} -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ibm-cp4ba-anyuid
imagePullSecrets:
- name: 'ibm-entitlement-key'
EOF

oc adm policy add-scc-to-user anyuid -z ibm-cp4ba-anyuid -n ${CP4BA_AUTO_NAMESPACE}
./cp4a-clusteradmin-setup.sh

# wait for operators ready

# before, 12 operators v23
oc get ClusterServiceVersion --no-headers
oc get ClusterServiceVersion --no-headers | wc -l


# create minimal cp4ba deployment

CP4BA_CLUSTER_NAME=${WFPS_NAMESPACE}
CP4BA_PLATFORM=OCP
CP4BA_AUTO_STORAGE_CLASS_FAST_ROKS="managed-nfs-storage"
CP4BA_AUTO_STORAGE_CLASS_BLOCK=thin-csi

cat <<EOF | oc create -f -
apiVersion: icp4a.ibm.com/v1
kind: ICP4ACluster
metadata:
  name: ${CP4BA_CLUSTER_NAME}
  namespace: ${CP4BA_AUTO_NAMESPACE}
  labels:
    app.kubernetes.io/instance: ibm-dba
    app.kubernetes.io/managed-by: ibm-dba
    app.kubernetes.io/name: ibm-dba
    release: 23.0.1
spec:
  appVersion: 23.0.1
  ibm_license: "accept"
  shared_configuration:
    show_sensitive_log: true
    sc_deployment_license: production
    sc_deployment_type: custom
    storage_configuration:
      sc_block_storage_classname: ${CP4BA_AUTO_STORAGE_CLASS_BLOCK}
      sc_dynamic_storage_classname: ${CP4BA_AUTO_STORAGE_CLASS_FAST_ROKS}
      sc_slow_file_storage_classname: ${CP4BA_AUTO_STORAGE_CLASS_FAST_ROKS}
      sc_medium_file_storage_classname: ${CP4BA_AUTO_STORAGE_CLASS_FAST_ROKS}
      sc_fast_file_storage_classname: ${CP4BA_AUTO_STORAGE_CLASS_FAST_ROKS}
    sc_deployment_platform: ${CP4BA_PLATFORM}
  ## this field is required to deploy Resource Registry (RR)
  resource_registry_configuration:
    replica_size: 1
EOF

# after, 16 operators v23
oc get ClusterServiceVersion --no-headers
oc get ClusterServiceVersion --no-headers | wc -l

# wait for all operators in state: Succeeded
```
