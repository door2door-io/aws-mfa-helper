# D2D AWS helper scripts

## create-mfa.sh

Create a new virtual Multi Factor Authentication device for your AWS user

Add `--string` parameter to use the string seed method instead of QR code

```
./create-mfa.sh <username> [--string]
```

## aws-mfa.sh

Run commands using cached temporary credentials using MFA and assumed role

Copy the `aws-mfa.sh` script to a location in your PATH

```
AWS_PROFILE=my-profile aws-mfa.sh <command>
```

## decrypt-gpg.sh and decrypt-keybase.sh

Decrypt content, like your AWS user password and secret key provided by your
AWS admin, using your GPG key or Keybase profile

```
./decrypt-gpg.sh '<content>'
```
