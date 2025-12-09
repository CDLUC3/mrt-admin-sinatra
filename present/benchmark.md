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

## Demo

### View the Benchmark Fixity Screens in the Admin Tool
<img width="865" height="494" alt="image" src="https://github.com/user-attachments/assets/a302085b-2cb8-478d-82cb-d70fa043491b" />

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

- https://github.com/CDLUC3/merritt-docker/blob/main/mrt-inttest-services/merritt-dev/scripts/run-file-benchmarks.sh

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

<img width="1239" height="510" alt="image" src="https://github.com/user-attachments/assets/024ed207-47ef-4675-838b-f5308065970b" />

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
