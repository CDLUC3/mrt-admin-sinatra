# Re-deploying EC2 with Auto-scaling Groups

## Problem To Solve

4-5 UC Campuses use IP-based authentication to allow Merritt to download content.

Our Nuxeo based deposits from those campuses do not have this limitation.

As we move to containers and the promise of auto-scaling services, the need to used fixed IP addresses does constrain our flexibility.

Fortunately, this will only be used by a small percentage of Merritt deposits.

## Desired Solution

We have a weekly script `deployStack.sh` that redeploys all of our ECS services while our processing queues are on hold.

We would like to force the rebuild ot our proxy server within the same window.

Ideally, we would like this to run by AWS cli commands (vs running Sceptre/Cloud Formation)

## Requirements
- A fixed IP address must be assigned to the instance (and re-assigned anytime the instance is re-generated)
- A DNS record must be assigned to the instance (and re-assigned anytime the instance is re-generated)
- A load balancer cannot be used due to the maximum configurable timeout for an ALB operation

## Solution Details

### Generate an Elastic IP (EIP)

```yaml
Resources:
  MerrittProxyEIP:
    Type: AWS::EC2::EIP 
    DeletionPolicy: "Retain"
    Properties:
      Tags:
        - Key: Name
          Value: MerrittProxyEIP

Outputs:
  MerrittProxyPublicIp:
    Description: EIP for the merritt proxy
    Value: !GetAtt MerrittProxyEIP.PublicIp
  MerrittProxyAllocationId:
    Description: EIP allocation ID for the merritt proxy
    Value: !GetAtt MerrittProxyEIP.AllocationId
```

### Rather than creating an EC2 Instance, Create an EC2 AutoScaling Group that will generate the instance

```yaml
  MerrittProxyASG:
    Type: AWS::AutoScaling::AutoScalingGroup
    Properties:
      AutoScalingGroupName: !Ref name
      LaunchTemplate:
        LaunchTemplateName: MerrittProxyLaunchTemplate
        Version: !GetAtt MerrittProxyLaunchTemplate.LatestVersionNumber
      MinSize: '1'
      MaxSize: '1'
      DesiredCapacity: '1'
      VPCZoneIdentifier:
        - {{sceptre_user_data.public_subnet_a}}
        - {{sceptre_user_data.public_subnet_b}}
        - {{sceptre_user_data.public_subnet_c}}
      Tags:
        - Key: Name
          Value: !Ref name
          PropagateAtLaunch: true
```

### Define the EC2 Properties within a Launch Template

```yaml
  MerrittProxyLaunchTemplate:
    Type: AWS::EC2::LaunchTemplate
    Properties:
      LaunchTemplateName: MerrittProxyLaunchTemplate
      LaunchTemplateData:
        InstanceType: !Ref instancetype
        ImageId: !Ref amiId
        IamInstanceProfile: 
          Name: !Ref MyInstanceProfile
        SecurityGroupIds:
          - !GetAtt MyEC2SG.GroupId
        UserData:
          Fn::Base64: !Sub |
            #!/bin/bash
            echo "Running EC2 UserData script" >> /tmp/userdata.log
            ...
```

### Create an Apache Forward Proxy

```bash
            dnf update -y
            dnf install -y httpd

            # Create a test landing page
            echo "<h1>Hello World from Proxy Linux Web Server!</h1>" > /var/www/html/index.html

            # Create forward proxy
            echo "ProxyRequests On" > /etc/httpd/conf.d/forwardProxy.conf
            echo "ProxyVia On" >> /etc/httpd/conf.d/forwardProxy.conf
            echo "<Proxy>" >> /etc/httpd/conf.d/forwardProxy.conf
            echo "Order deny,allow" >> /etc/httpd/conf.d/forwardProxy.conf
            echo "Deny from all" >> /etc/httpd/conf.d/forwardProxy.conf
            echo "Allow from all" >> /etc/httpd/conf.d/forwardProxy.conf
            echo "</Proxy>" >> /etc/httpd/conf.d/forwardProxy.conf

            # Listen on non-standard port
            sed -i 's/Listen 80/Listen {{sceptre_user_data.proxy_port}}/' /etc/httpd/conf/httpd.conf

            # Enable Apache to start automatically on system boot
            systemctl enable httpd
            systemctl start httpd
```

### Obtain the Instance ID and Private IP of the generated instance

```bash
            # Obtain the instance ID and private IP address of the EC2 instance
            TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
              -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
            # Get instance ID and Region
            INSTANCE_ID=$(curl -sH "X-aws-ec2-metadata-token: $TOKEN" \
              http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .instanceId)
            PRIVATE_IP=$(curl -sH "X-aws-ec2-metadata-token: $TOKEN" \
              http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .privateIp)
```

### Associate the EIP with the Instance

```bash
            # Associate the Elastic IP with the EC2 instance.
            # The allocationId of the Elastic IP is passed in as a parameter to the CloudFormation template.
            aws ec2 associate-address \
              --instance-id $INSTANCE_ID \
              --allocation-id {{sceptre_user_data.stack_parameters.eipAllocationId}} \
              --region us-west-2 2>&1 >> /tmp/userdata.log
```

### Assign a Route53 Address with the Instance

```bash
            aws route53 change-resource-record-sets --hosted-zone-id {{sceptre_user_data.hosted_zone}} --change-batch '{
              "Changes": [
                {
                  "Action": "UPSERT",
                  "ResourceRecordSet": {
                    "Name": "{{sceptre_user_data.stack_parameters.name}}.{{sceptre_user_data.domain}}",
                    "Type": "A",
                    "TTL": 60,
                    "ResourceRecords": [{"Value": "'$PRIVATE_IP'"}]
                  }
                }
              ]
            }' 2>&1 >> /tmp/userdata.log
```

### Create a Security Group allowing all Egress and Ingress from our ECS Stacks to the Proxy Port

```yaml
  MyEC2SG:
    Type: AWS::EC2::SecurityGroup
  MyEC2SGEgress:
    Type: AWS::EC2::SecurityGroupEgress
  {% for sg in sceptre_user_data.merritt_sgs %}
  MerrittDefaultSGIngress{{loop.index}}:
    Type: AWS::EC2::SecurityGroupIngress
  {% endfor %}
```

### Create an Instance Profile to Grant Permissions to the UserData script

```yaml
  MyInstanceProfile:
    Type: AWS::IAM::InstanceProfile
    Properties:
      InstanceProfileName: mrt-profile-ingest-asg-proxy
      Roles: 
      - !Ref MyInstanceRole
```

### Create The Role to all EIP Attach and Route 53 Update

```yaml
  MyInstanceRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: mrt-role-ingest-asg-proxy
      AssumeRolePolicyDocument:
        Version: 2012-10-17
        Statement:
          - Sid: AllowAwsEc2ToAssumeRole
            Effect: Allow
            Principal:
              Service: [ ec2.amazonaws.com ]
            Action: [ sts:AssumeRole ]
      Policies:
      - PolicyName: EIPAttach
        PolicyDocument:
          Statement:
          - Sid: AllowEIPAssociation
            Effect: Allow
            Action:
            - "ec2:AssociateAddress"
            Resource: 
            - !Sub "arn:aws:ec2:${AWS::Region}:${AWS::AccountId}:elastic-ip/{{sceptre_user_data.stack_parameters.eipAllocationId}}"
            - !Sub "arn:aws:ec2:${AWS::Region}:${AWS::AccountId}:instance/*"
          - Sid: AllowRoute53Change
            Effect: Allow
            Action:
            - "route53:ChangeResourceRecordSets"
            Resource: 
            - "arn:aws:route53:::hostedzone/{{sceptre_user_data.hosted_zone}}"
```

## Trigger the Cycling of the Instance

```bash
aws autoscaling start-instance-refresh --auto-scaling-group-name merritt-ingest-proxy-asg
```

Note that this has been integrated into our redeployStack.sh script
```bash
# pause ingest queue
aws ecs update-service --cluster $ECS_STACK_NAME --service ingest --force-new-deployment --desired-count 1 \
    --query 'service.{service:serviceName,status:status,desired:desiredCount,running:runningCount}' --output text --no-cli-pager
aws ecs update-service --cluster $ECS_STACK_NAME --service store --force-new-deployment --desired-count 1 \
    --query 'service.{service:serviceName,status:status,desired:desiredCount,running:runningCount}' --output text --no-cli-pager

aws autoscaling start-instance-refresh --auto-scaling-group-name merritt-ingest-proxy-asg

aws ecs wait services-stable --cluster $ECS_STACK_NAME \
    --services ingest store
# release ingest queue
```

## Not Yet Implemented

### Script Shutdown of a running instance (not applicable for our proxy)

```bash
aws autoscaling set-desired-capacity --desired-capacity 0
```

### Schedule Shutdown of a running instance

```yaml
Type: AWS::AutoScaling::ScheduledAction
Properties:
  AutoScalingGroupName: String
  DesiredCapacity: Integer
  EndTime: String
  MaxSize: Integer
  MinSize: Integer
  Recurrence: String
  StartTime: String
  TimeZone: String
```

## Other Concepts to Explore

- Add `LifecycleHookSpecificationList` to the Auto-Scaling Group
- Perhaps we could use a hook to attach/detach the EIP and the Route53 record on creation and termination

```
