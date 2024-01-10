#!/bin/bash

_me=$(basename "$0")

#--------------------------------------------------------
# read command line params
while getopts c:t: flag
do
    case "${flag}" in
        c) _CFG=${OPTARG};;
        t) _TRUST=${OPTARG};;
    esac
done

if [[ -z "${_CFG}" ]]; then
  echo "usage: $_me -c path-of-config-file -t path-of-trusted-certs-config-file"
  exit 1
fi
if [[ -z "${_TRUST}" ]]; then
  echo "usage: $_me -c path-of-config-file -t path-of-trusted-certs-config-file"
  exit 1
fi

export CONFIG_FILE=${_CFG}
export TRUST_CERTS_FILE=${_TRUST}

_SCRIPT_PATH="${BASH_SOURCE}"
while [ -L "${_SCRIPT_PATH}" ]; do
  _SCRIPT_DIR="$(cd -P "$(dirname "${_SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"
  _SCRIPT_PATH="$(readlink "${_SCRIPT_PATH}")"
  [[ ${_SCRIPT_PATH} != /* ]] && _SCRIPT_PATH="${_SCRIPT_DIR}/${_SCRIPT_PATH}"
done
_SCRIPT_PATH="$(readlink -f "${_SCRIPT_PATH}")"
_SCRIPT_DIR="$(cd -P "$(dirname -- "${_SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"

source $_SCRIPT_DIR/oc-utils.sh

CERT_FILE_TMP="./temp.crt"

#--------------------------------------------------------------
# get certificate from remote url
# $1: certificate url:port
getCertificate () {
  echo "Getting certificate from: "$1
  openssl s_client -showcerts -connect $1 2>/dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ${CERT_FILE_TMP}
}

#--------------------------------------------------------------
# create Secret 
createSecret () {
  SECRET_ALREADY_SET=$(oc get secret --no-headers $1 -n ${WFPS_NAMESPACE} 2>/dev/null | wc -l)
  if [[ "${SECRET_ALREADY_SET}" == "1" ]]; then
    echo "Deleting old secret "$1
    oc delete secret $1 -n ${WFPS_NAMESPACE} 2>/dev/null
  fi
  echo "Creating new secret "$1
  oc create secret generic $1 -n ${WFPS_NAMESPACE} --from-file=tls.crt=${CERT_FILE_TMP}
}

#--------------------------------------------------------------
# add Secrets 
addSecrets () {

  for i in {1..10}
  do
    _URL="TCERT_ENDPOINT_URL_"$i
    _CRT="TCERT_SECRET_NAME_"$i
    if [[ ! -z "${!_URL}" ]]; then
      echo ""
      echo "Working on ${!_URL} ${!_CRT}"
      getCertificate ${!_URL}
      createSecret ${!_CRT}
    fi
  done

  rm ${CERT_FILE_TMP}
  echo ""
}

#==========================================
echo ""
echo "*************************************"
echo "****** WfPS Runtime Deployment ******"
echo "*************************************"
echo "Using config file: "${CONFIG_FILE}
echo "Using certs file: "${TRUST_CERTS_FILE}

source ${CONFIG_FILE}

source ${TRUST_CERTS_FILE}

verifyAllParams
addSecrets
