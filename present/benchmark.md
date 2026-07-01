# CloudWatch Metrics for File Retrievals

## History

- Merritt Team experienced significant retrieval time delays with both of our non-AWS cloud storage providers
  - Fortunately, the issues occurred at different times, so we were able to isolate and diagnose the issue
- To do this we created a benchmark script that downloads a 100MB file and a 20MB file 6 different ways and cpatures benchmark times
  - From S3 using presigned file retrieval
  - From S3 using java streaming + fixity computation
  - From SDSC using presigned file retrieval
  - From SDSC using java streaming + fixity computation
  - From Wasabi using presigned file retrieval
  - From Wasabi using java streaming + fixity computation
- This matrix of retrieval allowed us to isolate performance issues
  - At a provider level
  - Within our Code vs within a default retrieval mechanism
- The Merritt Team downloaded relevant benchmark data to each of our vendors and was able to initiate a problem ticket

## Demo

### View the Benchmark Fixity Screens in the Admin Tool
<img width="865" height="494" alt="Admin Tool table illustrating benchmark options for 3 storage nodes (5001, 9501, 2001).  Extracted table data follows." src="https://github.com/user-attachments/assets/a302085b-2cb8-478d-82cb-d70fa043491b" />


### Table Data

| Node Number | Cloud Service | Audit Test | Access Test |
|---|---|---|---|
| 5001 | aws-s3 | [Audit Benchmark](#) | [Access Benchmark](#) |
| 9501 | sdsc   | [Audit Benchmark](#) | [Access Benchmark](#) |
| 2001 | wasabi | [Audit Benchmark](#) | [Access Benchmark](#) |

### Navigate to the Sample JSON entries
- Note the URL's that are provided for the purpose of running the benchmark tests

```
admin_access_url: "/ops/storage/benchmark-fixity-fileid?inv_file_id=114807569&node_number=9501&retrieval_method=audit&node_number=9501&retrieval_method=access",
admin_audit_url: "/ops/storage/benchmark-fixity-fileid?inv_file_id=114807569&node_number=9501&retrieval_method=audit&node_number=9501&retrieval_method=audit",
```
  
- Note the resulting data that is generated

```
results: {
  fixity_status: "verified",
  status: "INFO",
  retrieval_time_sec: 1.989132018003147
}
```

## Benchmark Script

- https://github.com/CDLUC3/merritt-docker/blob/main/mrt-inttest-services/merritt-ops/scripts/run-file-benchmarks.sh

### Result Data Extraction
```bash
  base="$(admintool_base)/ops/storage/benchmark-fixity-localid"
  url="${base}?localid=${localid}&filename=${filename}&node_number=${nodenum}&retrieval_method=${method}"
  curl --no-progress-meter -o /tmp/benchmark.json "$url" 

  stat=$(jq -r '.results.status' /tmp/benchmark.json)
  rettime=$(jq -r '.results.retrieval_time_sec' /tmp/benchmark.json)
  cloud=$(jq -r '.cloud_service' /tmp/benchmark.json)
  errormsg=$(jq -r '.results.error_message // ""' /tmp/benchmark.json)
```

### Save results to CloudWatch Metrics

```bash
aws cloudwatch put-metric-data --region us-west-2 --namespace merritt \
    --dimensions "filename=$filename,cloud_service=$cloud,retrieval_method=$method" \
    --unit Seconds --metric-name retrieval-duration-sec --value $rettime
```

## Retrieve Benchmark Data from CloudWatch Metrics

<img width="1239" height="510" alt="Sample benchmark readings for 3 storage nodes.  Sample readings extracted as text follows this image." src="https://github.com/user-attachments/assets/024ed207-47ef-4675-838b-f5308065970b" />

### Extracted Table Data

| Timestamp | aws-s3 access | aws-s3 audit | sdsc access | sdsc audit | wasabi access | wasabi audit |
|---|---:|---:|---:|---:|---:|---:|
| 2025-12-05 09:27:00 | 1.00 | 3.80 | 1.94 | 2.19 |  |  |
| 2025-12-05 09:42:00 |  |  |  |  | 231.12 | 207.23 |
| 2025-12-05 10:27:00 | 2.17 | 1.26 | 1.94 | 1.75 | 8.00 | 102.12 |
| 2025-12-05 15:42:00 | 3.53 | 1.19 | 9.59 | 1.91 | 57.69 | 29.68 |
| 2025-12-05 15:57:00 | 5.02 | 1.32 | 1.85 | 1.95 | 14.72 | 41.24 |
| 2025-12-05 16:42:00 | 3.76 | 1.24 | 1.89 | 1.83 | 45.14 |  |
| 2025-12-05 16:57:00 |  |  |  |  |  | 67.46 |
| 2025-12-05 21:57:00 | 3.65 | 1.39 | 1.80 | 1.93 | 32.76 | 4.41 |
| 2025-12-06 03:57:00 | 1.86 | 1.24 | 1.00 | 1.84 | 3.00 | 6.14 |
| 2025-12-06 09:57:00 | 2.56 | 1.24 | 1.81 | 1.87 | 4.34 | 5.19 |
| 2025-12-06 15:57:00 | 2.94 | 1.18 | 1.85 | 1.80 | 3.95 | 4.61 |


### Retrieval Script

- https://github.com/CDLUC3/mrt-admin-sinatra/blob/main/app/lib/client/cloudwatch/metrics.rb

### Create a CloudWatch "Metrics Query"

```ruby
    def metric_query(fname)
      query = []
      %w[aws-s3 sdsc wasabi].each do |cloud|
        %w[access audit].each do |method|
          query << {
            id: "#{cloud.gsub('-', '_')}_#{method}",
            metric_stat: {
              metric: {
                namespace: 'merritt',
                metric_name: 'retrieval-duration-sec',
                dimensions: [
                  { name: 'filename', value: fname },
                  { name: 'cloud_service', value: cloud },
                  { name: 'retrieval_method', value: method }
                ]
              },
              period: 15 * 60,
              stat: 'Average'
            },
            return_data: true
          }
        end
      end

      query
    end
```

### Convert the JSON output from the Metrics Query into a table

```ruby
    def retrieval_duration_sec_metrics(fname)
      return { message: 'CloudWatch client not configured' } unless enabled

      results = {}
      @cw_client.get_metric_data(
        metric_data_queries: metric_query(fname),
        start_time: Time.now - (7 * 24 * 3600),
        end_time: Time.now
      ).metric_data_results.each do |result|
        col = result.id
        result.timestamps.each_with_index do |tstamp, index|
          value = result.values[index]
          next unless value

          loctstamp = DateTime.parse(tstamp.to_s).to_time.localtime.strftime('%Y-%m-%d %H:%M:%S')

          results[loctstamp] ||= {}
          results[loctstamp][col] = value
        end
      end
      results.keys.sort.map do |tstamp|
        results[tstamp].merge({ timestamp: tstamp })
      end
    end
```

## Viewing the Data in CloudWatch in the AWS Console

Choose Access method across providers

<img width="916" height="446" alt="Screenshot of available CloudWatch metrics associated with the benchmark readings.  The 3 'access' 'retreival-duration-sec' readings for the file 100_mb_random.dat have been selected.  These readings correspond to the 3 storage nodes of interest." src="https://github.com/user-attachments/assets/aadb90cf-f9d6-4956-8359-401bb1e88a5c" />

<img width="1317" height="203" alt="Line chart graphing the 3 readings of interest between 2/12 - 2/18.  The 'wasabi' reading is the slowest." src="https://github.com/user-attachments/assets/facc372d-025f-41f5-9e70-4b71b350a379" />

Note how the graph changes when the focus is on fixity calculation

<img width="1318" height="175" alt="Line chart graphing 3 'audit' readings for the same 3 storage nodes between 2/12 - 2/18.  These numbers are based on a retrieval plus a fixity calculation.  There is less variation in the chart han in the prior chart." src="https://github.com/user-attachments/assets/49c79db0-ba4d-442a-aa8f-146917203bd3" />


## Notes About CloudWatch Metrics

- Data is meant to be numeric
- There are a pre-defined set of "Units" that can be applied to a metric
- Metrics can be isolated and differentiated
  - With a namespace
  - With a custom name
  - With custom dimensions
- CloudWatch expects metrics to be posted at regular intervals
  - ad-hoc entries require a custom solution like my code above
  - CloudWatch graphs assume that you will assign a duration that applies to your entries (6 hours in my example)
 
## CloudWatch metrics retention

- You cannot force the deletion of metrics
- Metrics that are not posted for 2 weeks will be purged by AWS
- Historical metrics are expired after 15 months
- https://repost.aws/knowledge-center/cloudwatch-delete-metric
