#!/bin/bash

AWS_CACHE_DIR="${HOME}/.aws/cli/cache"


cleanup() {
    rm -f ${CLEANUP_TEMP_FILES}
}


get_session_token() {
    PROFILE="${1}"
    MFA_SERIAL=$(aws configure get "profile.${PROFILE}.mfa_serial")
    if [ "${MFA_SERIAL}" == "" ]; then return; fi

    SOURCE_PROFILE=$(aws configure get "profile.${PROFILE}.source_profile")
    if [ "${SOURCE_PROFILE}" == "" ]
    then
        SOURCE_PROFILE="${PROFILE}"
    fi

    mkdir -p "${AWS_CACHE_DIR}"
    AWS_CACHE_FILE="${AWS_CACHE_DIR}/$(echo ${MFA_SERIAL} | sed -e 's/\//__/g' -e 's/:/--/g')"
    MUST_RENEW=1
    if [ -f "${AWS_CACHE_FILE}" ]
    then
        EXPIRATION=$(python -c 'import sys; import time; import datetime; dt = datetime.datetime.strptime(sys.argv[1], "%Y-%m-%dT%H:%M:%SZ"); print int(time.mktime(dt.timetuple()))' $(jq -r '.Credentials.Expiration' "${AWS_CACHE_FILE}"))
        if [ "${EXPIRATION}" != "" ]
        then
            NOW=$(date +"%s")
            # Don't renew if more than 5 minutes left to expire
            if [ $NOW -lt $((EXPIRATION - 300)) ]
            then
                MUST_RENEW=0
            fi
        fi
    fi
    if [ $MUST_RENEW -eq 1 ]
    then
        read -p "Please input MFA code: " MFA_CODE
        # Get a session credentials and token for the source profile
        # using mfa validation, set expiration to 36 hours
        aws sts get-session-token --serial-number "${MFA_SERIAL}" --token-code "${MFA_CODE}" --duration-seconds 129600 --profile "${SOURCE_PROFILE}" > "${AWS_CACHE_FILE}"
        if [ $? -ne 0 ]
        then
            echo "Unable to get-session-token!" >&2
            exit 1
        fi
    fi

    # Save mfa validated session credentials and token for source profile
    aws configure set "profile.${SOURCE_PROFILE}.aws_access_key_id" $(jq -r '.Credentials.AccessKeyId' "${AWS_CACHE_FILE}")
    aws configure set "profile.${SOURCE_PROFILE}.aws_secret_access_key" $(jq -r '.Credentials.SecretAccessKey' "${AWS_CACHE_FILE}")
    aws configure set "profile.${SOURCE_PROFILE}.aws_session_token" $(jq -r '.Credentials.SessionToken' "${AWS_CACHE_FILE}")
}


assume_role() {
    PROFILE="${1}"
    ROLE="${2}"
    if [ "${ROLE}" == "" ]; then return; fi
    echo "Setup AWS session for profile ${PROFILE} assuming role ${ROLE} ..." >&2

    SOURCE_PROFILE=$(aws configure get "profile.${PROFILE}.source_profile")

    # Set temp config for target profile with role_arn and source_profile
    # (skip mfa_serial as mfa session was already established)
    AWS_CONFIG_FILE=$(mktemp "${TMPDIR:-/tmp/}aws-config.XXXXXXXX")
    CLEANUP_TEMP_FILES="${CLEANUP_TEMP_FILES} ${AWS_CONFIG_FILE}"
    env AWS_CONFIG_FILE="${AWS_CONFIG_FILE}" aws configure set "profile.${PROFILE}.role_arn" "${ROLE}"
    env AWS_CONFIG_FILE="${AWS_CONFIG_FILE}" aws configure set "profile.${PROFILE}.source_profile" "${SOURCE_PROFILE}"

    # Let the aws cli call the assume-role indirectly by calling get-caller-identity
    # so it uses the source_profile credentials already validated by mfa
    # and populates cache credentials file automatically to reuse session while valid
    ASSUMED_ARN=$(env AWS_CONFIG_FILE="${AWS_CONFIG_FILE}" aws sts get-caller-identity --profile "${PROFILE}" | jq -e -r '.Arn')
    if [ "${ASSUMED_ARN}" == "" ]
    then
        echo "Failed to assume the role" >&2
        exit 1
    fi
    AWS_CACHE_FILE="$(grep -l ${ASSUMED_ARN} ${AWS_CACHE_DIR}/*)"

    # Export session credentials and token for target profile
    export AWS_ACCESS_KEY_ID=$(jq -r '.Credentials.AccessKeyId' "${AWS_CACHE_FILE}")
    export AWS_SECRET_ACCESS_KEY=$(jq -r '.Credentials.SecretAccessKey' "${AWS_CACHE_FILE}")
    export AWS_SESSION_TOKEN=$(jq -r '.Credentials.SessionToken' "${AWS_CACHE_FILE}")
}


# Setup cleanup handler on exit signal
trap cleanup EXIT

if [ "${AWS_PROFILE}" == "" ]
then
    echo "Missing AWS_PROFILE env variable!"
    exit 1
fi

# Create a temp credentials file if not already defined
if [ "${AWS_SHARED_CREDENTIALS_FILE}" == "" ]
then
    export AWS_SHARED_CREDENTIALS_FILE=$(mktemp "${TMPDIR:-/tmp/}aws-credentials.XXXXXXXX")
    CLEANUP_TEMP_FILES="${CLEANUP_TEMP_FILES} ${AWS_SHARED_CREDENTIALS_FILE}"
    cat ~/.aws/credentials > "${AWS_SHARED_CREDENTIALS_FILE}"
fi

# Get session credentials
get_session_token "${AWS_PROFILE}"
# Assume role if configured in profile
ROLE_ARN=$(aws configure get "profile.${AWS_PROFILE}.role_arn")
assume_role "${AWS_PROFILE}" "${ROLE_ARN}"

# Disable any AWS config present on the system before running command
export AWS_CONFIG_FILE="/dev/null"

# Export AWS_PROFILE
export AWS_PROFILE="${AWS_PROFILE}"

# Play time!
exec $@
