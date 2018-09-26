#!/bin/bash -x

APP_NAME="$(basename $0)"
DEFAULT_INDEX='1'
DEFAULT_CONFIG_FILE="${HOME}/.ol-schema2ldif.conf"
DEFAULT_OUTPUT_DIR='.'

function fullfilepath {
  local TARGET_FILE="${1}"
  pushd "$(dirname "${TARGET_FILE}")" 1>/dev/null
  if [ $? -ne 0 ] ; then
    return 1
  fi 
  local DIR_PATH=$(pwd -P)
  popd 1>/dev/null
  echo "${DIR_PATH}/$(basename "${TARGET_FILE}")"
  return 0 
}

#####################
### Load Defaults ###
#####################
CONFIG_FILE="${CONFIG_FILE:-$DEFAULT_CONFIG_FILE}"
if [ -f "${CONFIG_FILE}" ] ; then
  . "${CONFIG_FILE}"
fi

##########################
### Loading Parameters ###
##########################
DEP_SCHEMA_FILE_LIST=()
while [[ $# -gt 0 ]] ; do
  case "${1}" in
    --depends|-d)
      DEP_SCHEMA_FILE_LIST+=(${2})
      shift
    ;;
    --schema|-s)
      SCHEMA_FILE="${2}"
      shift
    ;;
    --index|-i)
      INDEX="${2}"
      shift
    ;;
    --output|-o)
      OUTPUT_DIR="${2}"
      shift
    ;;
    *)
      echo "${1} is an invalid parameter." 1>&2
      exit 2
    ;;
  esac
  shift
done

INDEX="${INDEX:-$DEFAULT_INDEX}"

#########################
### Verify Parameters ###
#########################

if [ -e "${SCHEMA_FILE}" ] ; then
  SCHEMA_FILE_FULL="$(fullfilepath "${1}")"
else 
  echo "Couldn't located ${SCHEMA_FILE}" 1>&2
  exit 3
fi 

if [ -z ${SLAPTEST_BIN} ] ; then
  WHEREIS_OUT="$(whereis -b slaptest)"
  if [ $? -eq 0 ] ; then
    SLAPTEST_BIN="$(echo "$WHEREIS_OUT"|cut -d\  -f 2)" 
  else 
    echo "Failed to locate slaptest binary" 1>&2
    exit 2
  fi
fi  
if [ ! -x "${SLAPTEST_BIN}" ] ; then
  echo "slaptest(${SLAPTEST_BIN}) binary is not found or not executable" 1>&2
  exit 2
fi 

DEP_SCHEMA_FILE_LIST_FULL=()
for FILE in ${DEP_SCHEMA_FILE_LIST[@]}; do
  if [ -e "${FILE}" ] ; then 
    DEP_SCHEMA_FILE_LIST_FULL+=($(fullfilepath "$FILE"))
  else
    echo "Could not locate dependancy schema file ${FILE}" 1>&2
    exit 3
  fi
done

if [ -z "${OUTPUT_DIR}" ] ; then
  echo "OUTPUT_DIR is not defined" 1>&2
  exit 3 
fi
  
LDIF_FILE_BASE="$(basename "${SCHEMA_FILE%.*}").ldif"

##############################
### Setup work environment ###
############################## 
WORK_DIR=$(mktemp -d --suffix="${APP_NAME}")
pushd "${WORK_DIR}" 1>/dev/null
mkdir converted.d

####################################
### Making dummy slapd.conf file ###
####################################
DEP_INCLUDE_STR=''
for INCLUDE_FILE in "${SCHEMA_FILE_LIST_FULL[@]}" ; do
   DEP_INCLUDE_STR="${DEP_INCLUDE_STR}include ${INCLUDE_FILE}"$'\n'
done

cat > dummy.conf << EOF
${DEP_INCLUDE_STR}
include ${SCHEMA_FILE_FULL}
EOF

#########################
### Converting config ###
#########################
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

pushd "converted.d/cn=config/cn=schema"
OUTPUT_DIR=$(find . -iname \*${SCHEMA_FILE_BASE})
