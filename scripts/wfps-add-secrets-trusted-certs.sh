#!/bin/bash

#set -euo pipefail


_me=$(basename "$0")

_ENV_CFG=""

#--------------------------------------------------------
_CLR_RED="\033[0;31m"   #'0;31' is Red's ANSI color code
_CLR_GREEN="\033[0;32m"   #'0;32' is Green's ANSI color code
_CLR_YELLOW="\033[1;33m"   #'1;32' is Yellow's ANSI color code
_CLR_BLUE="\033[0;34m"   #'0;34' is Blue's ANSI color code
_CLR_NC="\033[0m"


#--------------------------------------------------------
# read command line params
while getopts c:t:e: flag
do
    case "${flag}" in
        c) _CFG=${OPTARG};;
        t) _TRUST=${OPTARG};;
        e) _ENV_CFG=${OPTARG};;
    esac
done

usage () {
  echo "usage: $_me -c path-of-config-file -t path-of-trusted-certs-config-file -e full-path-to-target-environment-config-file"
  exit 1
}

if [[ -z "${_CFG}" ]]; then
  usage
fi
if [[ -z "${_TRUST}" ]]; then
  usage
fi

export TARGET_ENV_CONFIG_FILE=${_ENV_CFG}
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

mkdir -p $_SCRIPT_DIR/../output
CERT_FILE_TMP="$_SCRIPT_DIR/../output/temp-$USER-$RANDOM.crt"

#--------------------------------------------------------------
# get certificate from remote url
# $1: certificate url:port
getCertificate () {
  echo -e "${_CLR_GREEN}Getting certificate from '${_CLR_YELLOW}$1${_CLR_GREEN}'${_CLR_NC}"
  openssl s_client -showcerts -connect $1 2>/dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > "${CERT_FILE_TMP}"
}

#--------------------------------------------------------------
# create Secret 
createSecret () {
  SECRET_ALREADY_SET=$(oc get secret --no-headers $1 -n ${WFPS_NAMESPACE} 2>/dev/null | wc -l)
  if [[ "${SECRET_ALREADY_SET}" == "1" ]]; then
    echo -e "${_CLR_GREEN}Deleting old secret '${_CLR_YELLOW}$1${_CLR_GREEN}'${_CLR_NC}"
    oc delete secret $1 -n ${WFPS_NAMESPACE} 2>/dev/null 1>/dev/null
  fi
  echo -e "${_CLR_GREEN}Creating new secret '${_CLR_YELLOW}$1${_CLR_GREEN}'${_CLR_NC}"
  oc create secret generic $1 -n ${WFPS_NAMESPACE} --from-file=tls.crt="${CERT_FILE_TMP}" 2>/dev/null 1>/dev/null
}

#--------------------------------------------------------------
# add Secrets 
addSecrets () {

  for i in {1..10}
  do
    _OK=0
    _URL="TCERT_ENDPOINT_URL_"$i
    _CRT="TCERT_SECRET_NAME_"$i
    if [[ ! -z "${!_URL}" ]]; then
      echo ""
      echo -e "${_CLR_GREEN}Working on '${_CLR_YELLOW}${!_URL}${_CLR_GREEN}' for secret '${_CLR_YELLOW}${!_CRT}${_CLR_GREEN}'${_CLR_NC}"
      getCertificate ${!_URL}

      _IS_CERT=$(cat ${CERT_FILE_TMP} | wc -c)

      if [[ $_IS_CERT -gt 0 ]]; then
        _IS_CERT=$(grep "\-BEGIN CERTIFICATE-----" "${CERT_FILE_TMP}" | wc -l)
        if [[ $_IS_CERT -gt 0 ]]; then
          createSecret ${!_CRT}
          _OK=1
        fi      
      fi
      if [[ $_OK -eq 0 ]]; then
        echo -e "${_CLR_RED}Not a valid certificate from '${_CLR_YELLOW}${!_URL}${_CLR_RED}'${_CLR_NC}"
        echo -e "${_CLR_RED}Secret '${_CLR_YELLOW}${!_CRT}${_CLR_RED}' not created/updated.${_CLR_NC}"
      fi
      rm "${CERT_FILE_TMP}" 2>/dev/null
    fi
  done

  echo ""
}

#==========================================
echo ""
echo "*************************************"
echo -e "****** ${_CLR_YELLOW}WfPS Runtime Deployment${_CLR_NC} ******"
echo "*************************************"
echo -e "Using config file '${_CLR_YELLOW}${CONFIG_FILE}'${_CLR_NC}"
echo -e "Using target environment config file '${_CLR_YELLOW}${TARGET_ENV_CONFIG_FILE}'${_CLR_NC}"
echo -e "Using certs file '${_CLR_YELLOW}${TRUST_CERTS_FILE}'${_CLR_NC}"

sourceFile () {
  if [[ -f "${1}" ]]; then
    source ${1} 2> /dev/null 1> /dev/null
  else
    echo -e "${_CLR_RED}ERROR File not found '${_CLR_YELLOW}${1}${_CLR_RED}'${_CLR_NC}"
    exit 1
  fi
}

# Read target environment configuration, ignore error for IDP/LDAP configuration properties 
sourceFile "${TARGET_ENV_CONFIG_FILE}"
sourceFile ${CONFIG_FILE}
sourceFile ${TRUST_CERTS_FILE}

verifyAllParams
addSecrets
