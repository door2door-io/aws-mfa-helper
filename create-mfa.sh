#!/bin/bash

USERNAME="${1}"
METHOD="${2}"
PROFILE="my-d2d-user"
OUTFILE="${TMPDIR:-/tmp/}$(env LC_ALL=C < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)"
trap "{ rm -f ${OUTFILE}; }" EXIT

if [ "${METHOD}" = "string" ]
then
    SERIAL_NUMBER=$(aws iam create-virtual-mfa-device --virtual-mfa-device-name "${USERNAME}" --outfile "${OUTFILE}" --bootstrap-method Base32StringSeed --profile "${PROFILE}" | jq -r '.VirtualMFADevice.SerialNumber')
else
    read -p "Press ENTER when your MFA app on your smartphone is ready to scan the QR code..."
    SERIAL_NUMBER=$(aws iam create-virtual-mfa-device --virtual-mfa-device-name "${USERNAME}" --outfile "${OUTFILE}" --bootstrap-method QRCodePNG --profile "${PROFILE}" | jq -r '.VirtualMFADevice.SerialNumber')
fi

if [ "${SERIAL_NUMBER}" == "" ]
then
    echo "Error creating virtual MFA device ${USERNAME}"
    exit 1
fi

if [ $(uname) == "Darwin" ]
then
    open "${OUTFILE}"
else
    xdg-open "${OUTFILE}"
fi

read -p "First MFA code: " AUTH_CODE_1
read -p "Second MFA code: " AUTH_CODE_2
aws iam enable-mfa-device --user-name "${USERNAME}" --serial-number "${SERIAL_NUMBER}" --authentication-code-1 "${AUTH_CODE_1}" --authentication-code-2 "${AUTH_CODE_2}" --profile "${PROFILE}"
