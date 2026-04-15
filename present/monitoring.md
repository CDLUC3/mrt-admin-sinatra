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

- [run-monitor-checks.sh](https://github.com/CDLUC3/merritt-docker/blob/main/mrt-inttest-services/merritt-ops/scripts/run-monitor-checks.sh)
  - If the service resides in the main account, check each host individually
  - Check the "state" of a service as a whole
    - 200 return code
    - valid json returned
  - Check the status of specific json properties
  - Post health status to CloudWatch metrics
    - 1 Healthy
    - 0 Unhealthy
   
## CloudWatch Metrics

## CloudWatch Alarms

## Let AWS Do the Statistcal Work For Us

## Alarm Resolution

## Missing Metrics

## Escalope API

## Invoking Escalope with CloudWatch Alarm Data

## Resulting Slack Message

## Should this Be a Recommended Pattern to Follow?
