# Creating an Alarm on CloudWatch Log Groups

## Background

Jamie, our team member in New Zealand, noticed a spike in AWS Costs during our weekend.  Jamie traced these costs to CloudWatch Logs.

<img width="390" height="248" alt="Screenshot of AWS Cost Explorer showing a significant spike in CloudWatch charges between April 15-19" src="https://github.com/user-attachments/assets/4ceb8c85-f456-4d17-917f-c70e8feb7087" />

## How we isolated the problem

View Log Size for relevant log groups in CloudWatch.  Sort by size.

<img width="1067" height="219" alt="Screenshot of AWS Console showing 'stored bytes' for CloudWatch log groups.  Log groups have been sorted in descending order by 'stored bytes'" src="https://github.com/user-attachments/assets/946885fd-f987-40e3-b30d-941bbc00e20f" />

- One log was 300+ GB
- The other log was 90+ GB

## What Happened?

- Core dev service misconfigured on a Friday afternoon
- A bug prevented the nightly shutdown of the ECS stack
- Dependent services thrashed all weekend
- Existing services were logging multi-line stack traces over and over again
  - Each line was a new record import into CloudWatch
- On EC2, we would have filled the log disk
 
## CloudWatch is Powerful and Expensive

- Log retention can minimize storage costs
- BUT the ingest costs can be more expensive
- CloudWatch can do lots of filtering, but the ingest changes apply once the records are ingested.
- https://aws.amazon.com/cloudwatch/pricing/

<img width="626" height="412" alt="Screenshot of an AWS web page showing standard CloudWatch Logs ingest charges.  For the first 10TB ingested per month, there is a $.50 per GB charge." src="https://github.com/user-attachments/assets/8765753f-ed6a-4562-9514-09cb59477b77" />

## Remediation Plans

- Problem needed to be solved in the code, not in the infrastructure
- Eliminate chatty STDOUT logging (write stack traces as a single json record)
  - This was already a goal, but not a high priority
- Assign log levels (DEBUG, INFO, WARN)

## An additional Catch-all solution...

Examine the CloudWatch metrics for CloudWatch Logs...

<img width="648" height="183" alt="Screenshot of Graphed CloudWatch Metrics focusing on 'Incoming Bytes' between March 20 - April 30.  The graph illustrates the siginificant spike between Apr 15-19." src="https://github.com/user-attachments/assets/603a57ca-1fce-4421-9beb-e282e3e84e60" />

## Solution: Create a CW Alarm for a LogGroup when the Log Group has been created

- SUM the bytes sent to a CloudWatch Group in a 5 minute period
- It the log size exceeds a threshold for 3 5-minute periods in a row, notify Escalope
  - 1MB in Dev or Stage
  - 5MB in Prod
- Do not alarm on InsufficientData, it is normal to have no logging during a time period  

```yaml
  CloudwatchLogsGroup{{serviceNameCf}}:
    Type: 'AWS::Logs::LogGroup'
    Properties:
      LogGroupName: !Sub "/mrt/ecs/${env}/${svcname}"
      RetentionInDays: 7
  MrtAlarmLogInput{{serviceNameCf}}:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub "mrt_${env}_{{svcname}}_LogInput_Alarm"
      # Escalope payload goes into alarm description
      AlarmDescription: !Sub >-
        {
          "host": "merritt-${env}",
          "service": "{{svcname}}",
          "description": "Excessive log output for service '{{svcname}}' in ${env}"
        }
      ComparisonOperator: GreaterThanOrEqualToThreshold
      Dimensions: 
        - Name: LogGroupName
          Value: !Sub "/mrt/ecs/${env}/{{svcname}}"
      MetricName: IncomingBytes
      Namespace: AWS/Logs
      Statistic: Sum
      EvaluationPeriods: 3
      Threshold: {{sceptre_user_data.log_threshold_5min}}
      Period: 300
      Unit: Bytes
      {% if 'escalope_arn' in sceptre_user_data %}
      AlarmActions:
      - {{sceptre_user_data.escalope_arn}}
      OKActions:
      - {{sceptre_user_data.escalope_arn}}
      # Do not alarm insufficient data
      # InsufficientDataActions: 
      {% endif %}
```
