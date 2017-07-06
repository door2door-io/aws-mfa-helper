# D2D AWS helper scripts

## create-mfa.sh

Create a new virtual Multi Factor Authentication device for your AWS user

Add `--string` parameter to use the string seed method instead of QR code

```
./create-mfa.sh <username> [--string]
```

## aws-mfa.sh

Run commands using temporary credentials after authenticating using MFA and
assuming a role

Copy the `aws-mfa.sh` script to a location in your PATH

```
AWS_PROFILE=my-profile aws-mfa.sh <command>
```

## decrypt-gpg.sh and decrypt-keybase.sh

Decrypt content, like your AWS user password and secret key provided by your
AWS admin, using your PGP key or Keybase profile
