# Examples for v26

## Setup environment

```bash

# authoring namespace
_NAMESPACE_AUTH=cp4ba-baw-bai-auth

# runtime namespace
_NAMESPACE_RUN=cp4ba-os-bai-pfs-prod

# authoring host
_HOST_AUTH=cpd-cp4ba-baw-bai-auth.apps.itz-ldvw14.infra01-lb.wdc04.techzone.ibm.com

# baw utilies folder
_BAW_UTILS=/home/$USER$/cp4ba-projects/cp4ba-utilities/cp4ba-baw-applications
_WFPS_UTILS=/home/$USER/cp4ba-projects/cp4ba-wfps/scripts

```

## Create authoring certificate

Extract authoring environment certificate
```bash

_WK_FOLDER=/tmp/wfps-demo
mkdir -p "${_WK_FOLDER}"
cd ${_WK_FOLDER}

_CERT_FILE_TMP="${_WK_FOLDER}/cert.crt"
_SECRET_NAME=my-trusted-certs

rm "${_CERT_FILE_TMP}" 2>/dev/null
openssl s_client -showcerts -connect "${_HOST_AUTH}:443" 2>/dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > "${_CERT_FILE_TMP}"
cat "${_CERT_FILE_TMP}"

# save authoring certificate in runtime namespace
_SECRET_NAME=wfps-trusted-cert1
oc delete secret $_SECRET_NAME -n $_NAMESPACE_RUN 2>/dev/null 1>/dev/null
oc create secret generic $_SECRET_NAME -n $_NAMESPACE_RUN --from-file=tls.crt="$_CERT_FILE_TMP" 2>/dev/null 1>/dev/null
oc get secret $_SECRET_NAME -n $_NAMESPACE_RUN

```

# Applications in authoring env

```bash

cd "$_BAW_UTILS"
_BAS_URL=https://${_HOST_AUTH}/bas
_BAS_ADMIN=cp4admin
_BAS_ADMIN_PWD=dem0s

```

## List applications in authoring env

```bash

./cp4ba-bastudio-list-apps.sh -s ${_BAS_URL} -u ${_BAS_ADMIN} -p ${_BAS_ADMIN_PWD}

```

## List application versions in authoring env

```bash

_APP_NAME=SDWPSB1
./cp4ba-bastudio-list-apps.sh -s ${_BAS_URL} -u ${_BAS_ADMIN} -p ${_BAS_ADMIN_PWD} -n ${_APP_NAME} 

```

# Export apps from authoring env

```bash

if [[ -d "${_WK_FOLDER}" ]]; then
  rm ${_WK_FOLDER}/*.zip
  ls -al ${_WK_FOLDER}/*.zip
else
  mkdir -p "${_WK_FOLDER}"
fi

_APP_NAME=SDWPSB1
_APP_ACRONYM=1.0
_OUTPUT=${_WK_FOLDER}/${_APP_NAME}_${_APP_ACRONYM}.zip
./cp4ba-bastudio-export-app.sh -s ${_BAS_URL} -u ${_BAS_ADMIN} -p ${_BAS_ADMIN_PWD} -n ${_APP_NAME} -a ${_APP_ACRONYM} -f ${_OUTPUT}

ls -al ${_WK_FOLDER}/

```

# WfPS deployment

```bash

cd "${_WFPS_UTILS}"

```

## Install wfps1 (federated, administered by cpadmin)

```bash

WFPS_CONFIG=../configs/26/wfps-demo-pfs-1.properties
TARGET_ENV_CONFIG=../../cp4ba-installations/configs26/env1-runtime-os-bai-pfs.properties

# for trusted certs from host update 'TCERT_ENDPOINT_URL(*)' vars in ../configs/trusted-certs.properties
./wfps-add-secrets-trusted-certs.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG} -t ../configs/trusted-certs.properties

./wfps-deploy.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG}

```

## Show infos
```bash

./wfps-export-env-vars-to-file.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG}

```

# Application deployment

## Install application
```bash

./wfps-install-application.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG} -a ../apps/SimpleDemoWfPS1.zip

```

## Team bindings update with removal of users/groups from authoring
```bash

./wfps-update-team-bindings.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG} -t ../configs/team-bindings-app-1.properties -r

```

## List of deployed applications
```bash

./wfps-list-applications.sh -c ${WFPS_CONFIG} -e ${TARGET_ENV_CONFIG}

```



# Cleanup

```bash

cd
rm -fr "$_WK_FOLDER"

```
