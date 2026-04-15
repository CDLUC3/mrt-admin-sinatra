# Driving Escalope from CloudWatch Alarms

## Goal

- Migrate Nagios Checks + Escalope
- To Monitoring Scipt + CloudWatch Metrics + CloudWatch Alarms + Escalope

## Design Considerations

- Maintain monitoring configuration with ECS Stack Sceptre
- Deprecate Nagios checks that are less applicable to a container-based system
- Let each component do what it does best
- Hopefully simplify maintenance

## Monitoring and ECS

- ECS Monitors the health of individual service tasks
  - Best if the health check is lightweight 
- ALB's also monitor the health of the services they front
  - Best if the health check is lightweight 
- We are adding application-specific monitoring
  - We can tolerate a weightier check

## Monitoring Script

- [run-monitor-checks.sh](https://github.com/CDLUC3/merritt-docker/blob/main/mrt-inttest-services/merritt-ops/scripts/run-monitor-checks.sh#L140-L209)
  - If the service resides in the main account, check each host individually
  - Check the "state" of a service as a whole
    - 200 return code
    - valid json returned
  - Check the status of specific json properties
  - Post health status to CloudWatch metrics
    - 1 Healthy
    - 0 Unhealthy
   
## CloudWatch Metrics

```
aws cloudwatch put-metric-data --region us-west-2 --namespace merritt \
  --dimensions "stack=$MERRITT_ECS" \
  --unit Count --metric-name "$key" --value "$val"
```

## CloudWatch Metrics Graphs

<img width="419" height="257" alt="image" src="https://github.com/user-attachments/assets/637fd5f6-c580-42d7-9ae0-7ea2fd2316cd" />

<img width="910" height="524" alt="image" src="https://github.com/user-attachments/assets/c9604d6c-406a-4b24-870c-9c9ca5ed5af0" />

## CloudWatch Alarms

- [Alarm Configuration Yaml](https://github.com/CDLUC3/mrt-sceptre/blob/sprint-133/mrt-ecs/config/service_data.yaml#L513-L543)
- [Alarm Sceptre Template](https://github.com/CDLUC3/mrt-sceptre/blob/main/mrt-ecs/templates/stack.alarms.yaml.j2)

### Action Types
- SNS Channel (i.e. Slack, email)
- Lambda (i.e. Escalope)

### Event Handlers
- AlarmActions (Alarm Active)
- OKActions (Alarm Resolved)
- InsufficientDataActions (Metrics Missing)
  - This would be particularly tricky to script this ourselves! 

## CloudWatch Alarms Console View
<img width="1433" height="662" alt="image" src="https://github.com/user-attachments/assets/0ac27b2b-731f-406d-8f75-f189ada4b7f1" />

## Let AWS Do the Statistcal Work For Us

Our current cadence is to create CloudWatch Metrics every 5 minutes.

Alarms can test multiple time periods in order to trigger alarms.

```
      ComparisonOperator: LessThanThreshold
      Dimensions: 
        - Name: stack
          Value: {{sceptre_user_data.stack_parameters.env}}
        - Name: service
          Value: {{service}}
      MetricName: {{alarmrec.name}}
      Namespace: merritt
      Statistic: Average
      EvaluationPeriods: {{periods}}
      Threshold: 1
      Period: 300
```

## Escalope API Payload

A prior version of this script invoked Escalope directly.

```
local payload=$(jq -n \
    --arg host "ecs-uc3-mrt-$MERRITT_ECS-stack" \
    --arg service "$service" \
    --arg state "$state" \
    --arg cause "$cause" \
    '$ARGS.named')

  echo $payload

  curl -s -X POST -H "Content-Type: application/json" \
    "https://escalope.cdlib.org/notification_from_webcheck?CDLCognitoBypass=${escalope_token}" \
    -d "$payload" >/dev/null
```

## Invoking Escalope with CloudWatch Alarm Data

Martin is able to parse the CloudWatch Alarm data in order to call Escalope directly.

The ECS Stack Name becomes the Escalope "host".

Custom escalation rules can be set on a stack by stack basis.

## Resulting Slack Message

Alarm Message
```
Alert for host 'merritt-ecs-stg' - service 'ingest': state 'CRITICAL'. Cause: 'healthy-count'. You're the only contact in the chain.
```

Alarm Resolved
```
Event resolved: 'merritt-ecs-stg' - 'ingest' is now OK
```

## Should this Be a Recommended Pattern to Follow?
