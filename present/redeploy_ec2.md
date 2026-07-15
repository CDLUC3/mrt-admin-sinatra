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

### Create a Security Group for Egress and Ingress Rules

```yaml
MyEC2SG:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Enable all outgoing
      GroupName: "mrt-sg-ingest-asg-proxy"
      VpcId: {{sceptre_user_data.vpc_id}}
```

### Allow all Egress from EC2

```yaml
  MyEC2SGEgress:
    Type: AWS::EC2::SecurityGroupEgress
    Properties:
      GroupId: !GetAtt MyEC2SG.GroupId
      IpProtocol: -1
      FromPort: -1
      ToPort: -1
      CidrIp: '0.0.0.0/0'
      Description: Allow all outbound traffic from EC2 instance
``

  ### Allow Ingress from Merritt Stack Security Group on proxy port

  ```yaml
  {% for sg in sceptre_user_data.merritt_sgs %}
  MerrittDefaultSGIngress{{loop.index}}:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupId: !GetAtt MyEC2SG.GroupId
      IpProtocol: 'tcp'
      # IpProtocol: -1
      FromPort: {{sceptre_user_data.proxy_port}}
      ToPort: {{sceptre_user_data.proxy_port}}
      SourceSecurityGroupId: {{sg}}
      Description: Allow HTTP traffic from Merritt Stack SG
  {% endfor %}
```

### Create a Lifecycle Hook for Launch and Termination

```yaml
  AsgLaunchLifecycleHookLaunch:
    Type: AWS::AutoScaling::LifecycleHook
    Properties:
      AutoScalingGroupName: !Ref MerrittProxyASG
      LifecycleTransition: autoscaling:EC2_INSTANCE_LAUNCHING
      LifecycleHookName: !Sub "merritt-ingest-proxy-launch-hook"
      HeartbeatTimeout: 120
      DefaultResult: ABANDON
      NotificationMetadata: merritt-ingest-proxy
  AsgLaunchLifecycleHookTerminate:
    Type: AWS::AutoScaling::LifecycleHook
    Properties:
      AutoScalingGroupName: !Ref MerrittProxyASG
      LifecycleTransition: autoscaling:EC2_INSTANCE_TERMINATING
      LifecycleHookName: !Sub "merritt-ingest-proxy-terminate-hook"
      HeartbeatTimeout: 120
      DefaultResult: ABANDON
      NotificationMetadata: merritt-ingest-proxy
```

### Associate the Hooks with Launch and Termination

```yaml
  AsgLifecycleEventRule:
    Type: AWS::Events::Rule
    Properties:
      Name: merritt-ingest-proxy-asg-launch-hook-rule
      EventPattern:
        source:
          - aws.autoscaling
        detail-type:
          - EC2 Instance-launch Lifecycle Action
          - EC2 Instance-terminate Lifecycle Action
        detail:
          AutoScalingGroupName:
            - !Ref MerrittProxyASG
          LifecycleHookName:
            - merritt-ingest-proxy-launch-hook
            - merritt-ingest-proxy-terminate-hook
      Targets:
        - Arn: !GetAtt AsgLifecycleLambda.Arn
          Id: AsgLifecycleLambdaTarget
```

### Assign Permissions for Lifecycle Events

```yaml
  AsgLifecycleLambdaInvokePermission:
    Type: AWS::Lambda::Permission
    Properties:
      Action: lambda:InvokeFunction
      FunctionName: !Ref AsgLifecycleLambda
      Principal: events.amazonaws.com
      SourceArn: !GetAtt AsgLifecycleEventRule.Arn
```

### Grant Specific AWS Permissions to the Lambda Implementing the Hook

```yaml
  AsgLifecycleLambdaInvokePermission:
    Type: AWS::Lambda::Permission
    Properties:
      Action: lambda:InvokeFunction
      FunctionName: !Ref AsgLifecycleLambda
      Principal: events.amazonaws.com
      SourceArn: !GetAtt AsgLifecycleEventRule.Arn
  AsgLifecycleLambdaRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub "merritt-ingest-proxy-lifecycle-lambda-role"
      AssumeRolePolicyDocument:
        Version: "2012-10-17"
        Statement:
          - Effect: Allow
            Principal:
              Service: [lambda.amazonaws.com]
            Action: ["sts:AssumeRole"]
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
      Policies:
        - PolicyName: AsgLifecyclePolicy
          PolicyDocument:
            Version: "2012-10-17"
            Statement:
            - Sid: AllowEIPAssociation
              Effect: Allow
              Action:
              - "ec2:AssociateAddress"
              - "ec2:DisassociateAddress"
              Resource: 
              - !Sub "arn:aws:ec2:${AWS::Region}:${AWS::AccountId}:elastic-ip/{{sceptre_user_data.stack_parameters.eipAllocationId}}"
              - !Sub "arn:aws:ec2:${AWS::Region}:${AWS::AccountId}:instance/*"
            - Sid: DescribeInstances
              Effect: Allow
              Action:
              - ec2:DescribeInstances
              Resource: "*"
            - Sid: AllowRoute53Change
              Effect: Allow
              Action:
              - "route53:ChangeResourceRecordSets"
              Resource: 
              - "arn:aws:route53:::hostedzone/{{sceptre_user_data.hosted_zone}}"
            - Sid: AllowCompleteLifecycle
              Effect: Allow
              Action:
                - autoscaling:CompleteLifecycleAction
              Resource: "*"
```

### Lambda Code to Process Lifecycle Events

```yaml
  AsgLifecycleLambda:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: merritt-ingest-proxy-lifecycle
      Runtime: python3.12
      Handler: index.handler
      Timeout: 180
      Role: !GetAtt AsgLifecycleLambdaRole.Arn
      Environment:
        Variables:
          EIP_ALLOCATION_ID: "{{sceptre_user_data.stack_parameters.eipAllocationId}}"
          HOSTED_ZONE_ID: "{{sceptre_user_data.hosted_zone}}"
          DOMAIN_NAME: "{{sceptre_user_data.domain}}"
      Code:
        ZipFile: |
          import os
          import boto3
          import logging

          logger = logging.getLogger()
          logger.setLevel(logging.INFO)
```

### Extract Data from the Lifecycle Event

```python
          ec2 = boto3.client("ec2")
          asg = boto3.client("autoscaling")
          r53 = boto3.client("route53")

          def handler(event, context):
              logger.info(f"Event: {event}")
              
              detail = event["detail"]
              action = detail["Action"]
              logger.info(f"Lifecycle action: {action}")
              instance_id = detail["EC2InstanceId"]
              hook_name = detail["LifecycleHookName"]
              asg_name = detail["AutoScalingGroupName"]
              token = detail["LifecycleActionToken"]
              
              logger.info(f"Processing lifecycle hook for instance {instance_id} in ASG {asg_name}")

              allocation_id = os.environ["EIP_ALLOCATION_ID"]
              hosted_zone_id = os.environ["HOSTED_ZONE_ID"]
              domain_name = os.environ["DOMAIN_NAME"]
              hostname = detail["NotificationMetadata"]
              result = 'ABANDON'
              
              try:
                  response = ec2.describe_instances(InstanceIds=[instance_id])
                  logger.info(f"EC2 describe_instances response received")
                  
                  if response['Reservations']:
                    instance = response['Reservations'][0]['Instances'][0]
                    # tags = instance.get('Tags', [])
                    # hostname = next((tag['Value'] for tag in tags if tag['Key'] == 'Name'), None)
                    logger.info(f"Instance hostname: {hostname}")
                    
                    record_name = f"{hostname}.{domain_name}"
                    logger.info(f"Route53 record name: {record_name}")


                    try:
                      private_ip = instance['PrivateIpAddress']
                      logger.info(f"Instance private IP: {private_ip}")
```

### Launch Actions

```python
                      if action == 'Launch':
                        r53.change_resource_record_sets(
                          HostedZoneId=hosted_zone_id,
                          ChangeBatch={
                            "Comment": f"ASG lifecycle update for {instance_id}",
                            "Changes": [
                              {
                                "Action": "UPSERT",
                                "ResourceRecordSet": {
                                  "Name": record_name,
                                  "Type": "A",
                                  "TTL": 60,
                                  "ResourceRecords": [{"Value": private_ip}]
                                }
                              }
                            ]
                          }
                        )
                        logger.info(f"Route53 record updated successfully for {record_name}")
                        ec2.associate_address(
                            InstanceId=instance_id,
                            AllocationId=allocation_id,
                            AllowReassociation=True
                        )
                        logger.info(f"EIP associated with instance: {allocation_id}")
 ```

### Terminate Actions

```python
                      if action == 'Terminate':
                        r53.change_resource_record_sets(
                          HostedZoneId=hosted_zone_id,
                          ChangeBatch={
                            "Comment": f"ASG lifecycle update for {instance_id}",
                            "Changes": [
                              {
                                "Action": "DELETE",
                                "ResourceRecordSet": {
                                  "Name": record_name,
                                  "Type": "A",
                                  "TTL": 60,
                                  "ResourceRecords": [{"Value": private_ip}]
                                }
                              }
                            ]
                          }
                        )
                        logger.info(f"Route53 record deleted successfully for {record_name}")
                        ec2.disassociate_address(
                            InstanceId=instance_id,
                            AllocationId=allocation_id
                        )
                        logger.info(f"EIP disassociated with instance: {allocation_id}")
```

### Trigger Hook Completion

```python
                      result = "CONTINUE"

                    except Exception as e:
                      logger.error(f"Error updating Route53 record: {str(e)}", exc_info=True)
                      result = "ABANDON"
                  else:
                    logger.error(f"No reservations found for instance {instance_id}")
                    result = "ABANDON"
                    
              except Exception as e:
                  logger.error(f"Error processing lifecycle hook: {str(e)}", exc_info=True)
                  result = "ABANDON"

              logger.info(f"Completing lifecycle action with result: {result}")
              asg.complete_lifecycle_action(
                  LifecycleHookName=hook_name,
                  AutoScalingGroupName=asg_name,
                  LifecycleActionToken=token,
                  LifecycleActionResult=result
              )
              logger.info(f"Lifecycle action completed")
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
aws autoscaling set-desired-capacity --desired-capacity 0 \
  --auto-scaling-group-name merritt-ingest-proxy-asg
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

