# ECS Step Auto-Scaling using CloudWatch Metrics

## Merritt Logs Custom Metrics every 5 minutes

```json
{
    num_jobs_processing: 9,
    num_jobs_completed: 4,
    num_jobs_failed: 0,
    gb_in_process: 9.63,
    num_assemblies_completed: 11,
    num_assemblies_failed: 0,
    num_assemblies_processing: 0,
    num_batches_processing: 1,
    num_batches_completed: 3,
    num_batches_failed: 0,
    number_of_active_replications: 63,
    gb_to_be_replicated: 3.8,
    audit_online_file_count: 0,
    gb_audited_online: 0,
    audit_nearline_file_count: 0,
    oldest_audit_in_days: 0,
    gb_ingested: 0
}
```

## Create An Step Auto-Scaling Policy for ECS Services

### Service Auto-Scaling Config
```yaml
template:
  path: scale.queue.yaml.j2

parameters:
  count: '1'
  maxcount: '3'
  svcname: ingest
  cluster: !stack_output ecs-dev/ecs-cluster.yaml::MrtEcsClusterName
```

### Service Auto-Scaling Template

```yaml
Resources:
  ScalableTarget:
    Type: AWS::ApplicationAutoScaling::ScalableTarget
    Properties:
      MaxCapacity: {{maxcount}}
      MinCapacity: {{count}}
      ServiceNamespace: 'ecs'
      ScalableDimension: 'ecs:service:DesiredCount'
      ResourceId: !Sub 'service/${cluster}/${svcname}'
  ScaleUpPolicy:
    Type: AWS::ApplicationAutoScaling::ScalingPolicy
    Properties:
      PolicyName: {{svcname}}-scale-up
      PolicyType: StepScaling
      ScalingTargetId: !Ref ScalableTarget
      # CW looks for 3 datapoints over 3 minutes to add capacity
      # CW looks for 15 datapoints over 15 minutes to reduce capacity
      StepScalingPolicyConfiguration:
        AdjustmentType: ChangeInCapacity
        Cooldown: 300
        MetricAggregationType: Average
        StepAdjustments:
          - MetricIntervalLowerBound: 0
            ScalingAdjustment: 1
  ScaleDownPolicy:
    Type: AWS::ApplicationAutoScaling::ScalingPolicy
    Properties:
      PolicyName: {{svcname}}-scale-down
      PolicyType: StepScaling
      ScalingTargetId: !Ref ScalableTarget
      StepScalingPolicyConfiguration:
        AdjustmentType: ChangeInCapacity
        Cooldown: 300
        MetricAggregationType: Average
        StepAdjustments:
          - MetricIntervalUpperBound: 0
            ScalingAdjustment: -1
Outputs:
  ScalingPolicyUp:
    Description: "ARN of the scale up policy"
    Value: !Ref ScaleUpPolicy
  ScalingPolicyDown:
    Description: "ARN of the scale down policy"
    Value: !Ref ScaleDownPolicy
```


## Create An Alarm based on `num_jobs_processing`

### Metric Alarm Config

```yaml
template:
  path: scale.alarm.jobs.yaml.j2

parameters:
  env: ecs-dev
  ingestscaleup: !stack_output ecs-dev/scale-ingest.yaml::ScalingPolicyUp
  ingestscaledown: !stack_output ecs-dev/scale-ingest.yaml::ScalingPolicyDown
  storescaleup: !stack_output ecs-dev/scale-store.yaml::ScalingPolicyUp
  storescaledown: !stack_output ecs-dev/scale-store.yaml::ScalingPolicyDown
  value: 100
```

### Metric Alarm Template

Auto-Scaling Policy ARN's are triggered by alarms.

```yaml
Resources:
  MrtScalerAlarmJobs{{env}}:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: mrt_scaler_alarm_jobs_{{env}}
      # Escalope payload goes into alarm description
      ComparisonOperator: GreaterThanOrEqualToThreshold
      Dimensions: 
        - Name: stack
          Value: !Ref env
      MetricName: num_jobs_processing
      Namespace: merritt
      Statistic: Average
      EvaluationPeriods: 1
      Threshold: !Ref value
      Period: 60
      Unit: Count
      AlarmActions:
      - !Ref ingestscaleup
      - !Ref storescaleup
      OKActions:
      - !Ref ingestscaledown
      - !Ref storescaledown 
```

## Team Questions

- At what number of jobs should we scale up?
  - 20?
  - 50?
  - 100?
- At/below what number of jobs should we scale down?
  - same as above?
  - only scale down if the queue clears?
- Cooldown Period (between changes)
  - Scale up: 5 minutes
  - Scale down: 5 minutes
  - If we only scale down at 0, we could set this lower?
- What range should we allow in each environment?
  - DEV: 1-3 workers?
  - STG: 2-4 workers?
  - PRD: 2-5 workers?

## Design Implication

### Option 1
- Create scale-up/scale-down at N active jobs

### Option 2
- Create scale-up at N active jobs
- Create scale-down only at 0 active jbos