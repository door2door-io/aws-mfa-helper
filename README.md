# D2D AWS helper scripts

## decrypt-gpg.sh and decrypt-keybase.sh

Decrypt data, like your AWS user password and secret key provided by your
AWS admin, using your GPG key or Keybase profile

```
./decrypt-gpg.sh '<encrypted-data>'
```

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

## connect-ec2.sh

Returns the command in order to connect with a certain EC2 instance given a `Name` tag and the AWS profile.

```
./connect-ec2.sh <aws-profile> <EC2-instance-Name-Tag>
```
