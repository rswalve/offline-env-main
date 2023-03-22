# Offline Test Environment Setup

This project contains code to stand up a test environment meant to simulate our target environment on site.

Our target envrironment is SIPR and JWICS, which are air-gapped AWS cloud environments.  Aside from yum repos for Red Hat, there are limited resources available outside of AWS services.  For example, there is no container registry (other than ECR), there's no git server, and etc

The test environment that will be created consists of two VPCs - a source vpc and a target vpc.  

The two VPCs will be connected via a peering connection.  

The source VPC will contain a single subnet with a single management server which is where our installation process will be run.  The only external connectivity will be SSH to the management server from a single remote server (e.g., your laptop).  

Because there is no external internet connectivity, we cannot use the public AWS API endpoints.  Instead, the source VPC
is configured with VPC endpoints for each of the AWS services that we'll need access to.  Note that this is not the case on site - VPCs there should have access to the 'public' AWS API endpoints.  (we're using the VPC endpoints because that's the easiest way to simulate the connectivity on site)

The target VPC will be empty, though this may change depending on what we find M2O will provide when we asked for a new VPC (it might come with a default subnet).  We'll adjust our code here as we find out more about the target environment.  Our installation process should assume that it is responsible for deploying everything that is needed, including VPC endpoints.

The project also includes a Hashicorp packer module for creating the ami to be used for the managment server in the source vpc.  If you're running this in us-gov-west-1, you dont need to run it as the ami has already been created in that region.


## Usage

To create the environment, run the terraform.  The terraform will output the public IP of the management server.  It also generates the aws key pair; you can get the private key with
```
terraform output -json | jq -r '.ssh_private_key.value' > ssh_key.pem
```
and then to connect to the managment server
```
ssh -i ssh_key.pem centos@<ip address>
```

The management server has terraform, the aws cli and kubectl installed on it.


### Verifying connectivity
- ssh to mgmt server
- ssh from mgmt server to testbox
- access vpc endpoints from mgmt box
  - aws s3 ls 
  - aws ec2 describe-availability-zones 
  - aws sts get-caller-identity
  - aws elbv2 describe-account-limits
  
