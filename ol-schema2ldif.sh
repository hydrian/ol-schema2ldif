#!/bin/env -s bash

DEFAULT_INDEX='1'
DEFAULT_CONFIG_FILE="${HOME}/.ol-schema2ldif.conf"

function fullfilepath {
  local TARGET_FILE="${1}"
  local FULLPATH
  
  pushd "$(dirname "${TARGET_FILE}")" 1>/dev/null 
  DIR_PATH=$(pwd -P)
  popd 1>/dev/null
  echo "${DIR_PATH}/$(basename ${TARGET_FILE})"
  return 0 
}

CONFIG_FILE="${CONFIG_FILE:-$DEFAULT_CONFIG_FILE}"
if [ -f "${CONFIG_FILE}" ] ; then
  . "${CONFIG_FILE}"
fi



INDEX="${INDEX:-$DEFAULT_INDEX}"
SCHEMA_FILE=''

LDIF_FILE=''


if [ ! -z ${SLAPTEST_BIN} ] ; then
  WHEREIS_OUT="$(whereis -b slaptest)"
  if [ $? -eq 0 ] ; then
    SLAPTEST_BIN="$(echo "$WHEREIS_OUT"|cut -d\  -f 2)" 
  else 
    echo "Failed to locate slaptest binary" 1>&2
    exit 2
  fi
fi  
if [ ! -x "${SLAPTEST_BIN}" ] ; then
  echo "slaptest(${SLAPTEST_BIN} binary is not found or not executable" 1>&2
  exit 2
fi 


if [ ! -f "${SCHEMA_FILE}" ] ; then
  echo "Failed to read schema file ${SCHEMA_FILE}" 1>&2
  exit 2
fi
SCHEMA_FILE_FULL="$(fullfilepath ${SCHEMA_FILE})"
SCHEMA_FILE_BASE="$(basename ${SCHEMA_FILE_FULL}"
LDIF_FILE_BASE="${SCHEMA_FILE_BASE%.*}.ldif"
##############################
### Setup work environment ###
############################## 
WORK_DIR=$(mktemp -d --suffix="$(basename "$0")"
cp "${SCHEMA_FILE_FULL}" "${WORK_DIR}"
if [ $? -ne 0 ] ; then
  echo "Failed to copy ${SCHEMA_FILE_FULL} to work directory" 1>&2
  exit 2
fi 
pushd "${WORK_DIR}" 1>/dev/null

####################################
### Making dummy slapd.conf file ###
####################################
cat EOF >> dummy.conf
include "${SCHEMA_FILE_BASE}"
EOF
mkdir converted.d
"${SLAPTEST_BIN}" -f dummy.conf -F converted.d
if [ $? -ne 0 ] ; then
  echo "slaptest convert from schema to ldif failed" 1>&2 
  exit 2   
fi

##################
### Reindexing ###
##################
if [ ${INDEX} -ne 1 ] ; then
  true
fi