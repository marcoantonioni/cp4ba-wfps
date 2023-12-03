# cp4ba-wfps-utils


## Simple Deploy - new instance of WfPS with a dedicated PostgreSQL database
```
./wfps-deploy.sh -c ./configs/wfps1.properties
```

## Install application
```
./wfps-install-application.sh -c ./configs/wfps1.properties -a ../apps/SimpleDemoWfPS.zip
```

## Example of REST services invocations usin curl
```
# 
./exportWfPSEnvVars.sh -c ./configs/wfps1.properties && source ./exp.vars

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
```

## Prerequisites

```
source ./configs/wfps1.properties

# set target namespace
export CP4BA_AUTO_NAMESPACE=${WFPS_NAMESPACE}

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

CP4BA_CLUSTER_NAME=icp4deploy-wfps
CP4BA_PLATFORM=OCP
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

# wait for Zen operator and others ready
```
