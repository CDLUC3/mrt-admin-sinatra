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

<img width="1433" height="662" alt="image" src="https://github.com/user-attachments/assets/0ac27b2b-731f-406d-8f75-f189ada4b7f1" />


## Let AWS Do the Statistcal Work For Us

## Alarm Resolution

## Missing Metrics

## Escalope API

## Invoking Escalope with CloudWatch Alarm Data

## Resulting Slack Message

## Should this Be a Recommended Pattern to Follow?
