# AWS IAM Policy Templates and Testing

This directory contains AWS IAM policy templates and comprehensive testing scripts for validating IAM permissions in AWS environments.

## Overview

The IAM module provides a restrictive yet functional IAM policy template designed for development and testing environments. It follows the principle of least privilege while allowing necessary operations for EC2, S3, VPC, and networking resources.

## Files

### Policy Template
- *aws_iam_policy_template.json* - Main IAM policy template with granular permissions

### Testing Scripts
- *aws_policy_test.sh* - Comprehensive test suite validating all policy permissions
- *aws_deny_test.sh* - Tests specifically for denied actions to ensure restrictions work
- *aws_live_resource_test.sh* - Creates real AWS resources for manual verification (⚠️ incurs costs)
- *simple_aws_test.sh* - Lightweight version of the policy test suite

## Policy Permissions

### Allowed Actions

#### IAM Self-Management
- Manage own access keys (iam:ListAccessKeys, iam:CreateAccessKey, iam:DeleteAccessKey)
- Change own password (iam:ChangePassword)
- Get user information (iam:GetUser)

#### S3 Read-Only Access
- List and read all S3 buckets and objects
- Get bucket metadata and versioning information
- *Note*: Write operations are explicitly denied

#### EC2 Instance Management
- Launch instances in us-east-1 and us-east-2 regions only
- Restricted to t2.micro and t2.medium instance types
- Full lifecycle management (start, stop, terminate, reboot)
- Attach/detach IAM instance profiles

#### EBS Volume Management
- Create, attach, and delete volumes up to 50GB
- Volume operations limited to allowed regions

#### VPC and Networking
- Full VPC management (create, delete, modify)
- Subnet and network interface management
- Security group operations
- NAT Gateway and Internet Gateway management
- Route table and routing operations

#### Key Pair Management
- Create, delete, and import key pairs in allowed regions

### Denied Actions

#### S3 Restrictions
- Cannot create or delete buckets
- Cannot upload or delete objects
- Read-only access enforced via explicit deny

#### EC2 Restrictions
- Cannot launch instances outside us-east-1 and us-east-2
- Cannot use instance types other than t2.micro and t2.medium
- Cannot create volumes larger than 50GB

#### Regional Restrictions
- Key pair operations restricted to us-east-1 and us-east-2
- Most EC2 operations limited to these regions

## Usage

### 1. Deploy the Policy

Replace ACCOUNT_ID placeholder in the policy template with your actual AWS account ID:

bash
sed 's/ACCOUNT_ID/123456789012/g' aws_iam_policy_template.json > aws_iam_policy.json


Then create the policy in AWS using below or using aws console:

bash
aws iam create-policy \
  --policy-name RestrictedDeveloperPolicy \
  --policy-document file://aws_iam_policy.json \
  --description "Restricted policy for development environments"


### 2. Run Tests

#### Quick Test
bash
chmod +x simple_aws_test.sh
./simple_aws_test.sh


#### Comprehensive Test Suite
bash
chmod +x aws_policy_test.sh
./aws_policy_test.sh


#### Test Denied Actions
bash
chmod +x aws_deny_test.sh
./aws_deny_test.sh


#### Live Resource Test (⚠️ Creates Real Resources)
bash
chmod +x aws_live_resource_test.sh
./aws_live_resource_test.sh


## Test Results Interpretation

### Expected Outcomes
- *ALLOW*: Action should succeed (or show DryRunOperation for dry-run tests)
- *DENY*: Action should fail with AccessDenied or UnauthorizedOperation

### Test Categories
1. *S3 Tests*: Verify read access and write restrictions
2. *EC2 Launch Tests*: Validate instance type and region restrictions
3. *EBS Tests*: Check volume size limits
4. *VPC Tests*: Confirm networking permissions
5. *Key Pair Tests*: Verify regional restrictions

## Sample Test Output

### Comprehensive Policy Test (aws_policy_test.sh)

bash
$ bash aws_policy_test.sh
AWS IAM Policy Validation Test Suite
================================================
Running tests for Account ID: [ACCOUNT_ID]
================================================
Fetching valid AMIs...
Using AMIs: us-east-1=ami-[AMI_ID], us-east-2=ami-[AMI_ID], us-west-1=ami-[AMI_ID]

--- S3 Access Tests ---
PASS | S3 List Buckets | Expected: ALLOW | Actual: ALLOW
PASS | S3 Get Bucket Location | Expected: ALLOW | Actual: ALLOW
PASS | S3 Create Bucket | Expected: DENY | Actual: DENY

--- EC2 Instance Launch Tests ---
PASS | Launch t2.micro (us-east-1) | Expected: ALLOW | Actual: ALLOW
PASS | Launch t2.medium (us-east-2) | Expected: ALLOW | Actual: ALLOW
PASS | Launch t2.small (Denied Type) | Expected: DENY | Actual: DENY
PASS | Launch t2.micro (us-west-1) | Expected: DENY | Actual: DENY

--- EBS Volume Tests ---
PASS | Create 50GB Volume (us-east-1) | Expected: ALLOW | Actual: ALLOW
PASS | Create 51GB Volume (Limit Exceeded) | Expected: DENY | Actual: DENY

--- VPC & Networking Tests ---
PASS | Create VPC | Expected: ALLOW | Actual: ALLOW
PASS | Create Security Group | Expected: ALLOW | Actual: ALLOW

--- Key Pair Tests ---
PASS | Create Key Pair (us-east-1) | Expected: ALLOW | Actual: ALLOW
PASS | Create Key Pair (us-west-1) | Expected: DENY | Actual: DENY

--- Read-Only Operations ---
PASS | Describe Instances | Expected: ALLOW | Actual: ALLOW

================================================
Summary: 14 PASSED | 0 FAILED | Total: 14
================================================
ALL TESTS PASSED


### Simple Policy Test (simple_aws_test.sh)

bash
$ bash simple_aws_test.sh
Running Simple AWS Policy Tests...
Using AMI: ami-[AMI_ID]
Testing: S3 List Buckets
Result: ALLOWED
--------------------------------
Testing: Launch t2.micro us-east-1
Result: ALLOWED (Dry Run Success)
--------------------------------
Testing: Launch t2.small (Denied)
Result: DENIED
--------------------------------
Testing: Create 50GB Volume
Result: ALLOWED (Dry Run Success)
--------------------------------
Testing: Create 51GB Volume (Denied)
Result: DENIED
--------------------------------
Done.


### Deny Policy Test (aws_deny_test.sh)

bash
$ bash aws_deny_test.sh
AWS Deny Policy Validation
This script attempts actions that SHOULD FAIL.
================================================
Fetching AMIs...
Testing: Create S3 Bucket... PASS (Correctly Denied)
Testing: Launch t2.small (Denied Type)... PASS (Correctly Denied)
Testing: Launch in us-west-1 (Denied Region)... PASS (Correctly Denied)
Testing: Create 51GB Volume (Denied Size)... PASS (Correctly Denied)
Testing: Create Key Pair in us-west-1 (Denied Region)... PASS (Correctly Denied)
================================================
Done.


### Live Resource Test (aws_live_resource_test.sh)

bash
$ bash aws_live_resource_test.sh
WARNING: This script will create REAL resources in us-east-1.
Resources to be created:
- Key Pair
- Security Group
- t2.micro EC2 Instance
- 50GB EBS Volume

Do you want to proceed? (y/n) y
Fetching AMI...
Using AMI: ami-[AMI_ID]

1. Creating Key Pair: test-key-[TIMESTAMP]
Success

2. Creating Security Group: test-sg-[TIMESTAMP]
Success: sg-[SG_ID]

3. Launching Instance (t2.micro)
Success: i-[INSTANCE_ID]
Waiting for instance to be running...
Instance is running.

4. Creating 50GB Volume
Success: vol-[VOLUME_ID]
Waiting for volume to be available...
Volume is available.

=========================================
Resources Created for Manual Verification:
Key Pair: test-key-[TIMESTAMP] (test-key-[TIMESTAMP].pem)
Security Group: sg-[SG_ID] (test-sg-[TIMESTAMP])
Instance: i-[INSTANCE_ID]
Volume: vol-[VOLUME_ID]
=========================================

Press ENTER to cleanup all resources...

Cleaning up...
Terminating Instance: i-[INSTANCE_ID]
Waiting for termination...
Deleting Volume: vol-[VOLUME_ID]
Deleting Security Group: sg-[SG_ID]
Deleting Key Pair: test-key-[TIMESTAMP]
Cleanup Complete.


## Security Considerations

### Principle of Least Privilege
- Policy grants minimum permissions needed for development work
- Explicit denies prevent privilege escalation
- Regional restrictions limit blast radius

### Resource Limits
- Instance types limited to cost-effective options
- Volume sizes capped to prevent excessive storage costs
- Operations restricted to specific regions

### Self-Service Capabilities
- Users can manage their own access keys and passwords
- No ability to modify other users' permissions
- Instance profile attachment allowed for application roles

## Customization

### Adding Regions
To allow operations in additional regions, update the resource ARNs:

json
"Resource": [
    "arn:aws:ec2:us-east-1:ACCOUNT_ID:instance/*",
    "arn:aws:ec2:us-east-2:ACCOUNT_ID:instance/*",
    "arn:aws:ec2:NEW-REGION:ACCOUNT_ID:instance/*"
]


### Adding Instance Types
Update the condition in the EC2RunInstancesInstances statement:

json
"Condition": {
    "StringEquals": {
        "ec2:InstanceType": [
            "t2.micro",
            "t2.medium",
            "t3.small"
        ]
    }
}


### Increasing Volume Limits
Modify the NumericLessThanEquals condition:

json
"Condition": {
    "NumericLessThanEquals": {
        "ec2:VolumeSize": 100
    }
}


## Troubleshooting

### Common Issues

1. *AMI Not Found*: Tests use Amazon Linux 2 AMIs which may vary by region
2. *Account ID Mismatch*: Ensure ACCOUNT_ID is correctly replaced in policy
3. *Region Restrictions*: Verify operations are attempted in allowed regions only
4. *AWS CLI Configuration*: Ensure AWS credentials are properly configured

### Debug Mode
Add set -x to any test script for verbose output:

bash
#!/bin/bash
set -x  # Enable debug mode
# ... rest of script


## Best Practices

1. *Test Before Deployment*: Always run the test suite before applying policies
2. *Regular Validation*: Periodically re-run tests to ensure policy effectiveness
3. *Monitor Usage*: Review CloudTrail logs for policy violations
4. *Version Control*: Track policy changes and test results
5. *Documentation*: Keep this README updated with any customizations