This workflow shows how to take a run.id, select an iteration, then calculate the primary_metric result for that iteration

- This is a work-in-progress and is not complete
- This assumes you have run data in ES, from pbench or other benchmark which is adhering to CDM
- The queries use curl and are expected to be run in a script or terminal prompt, but could be adapted to any method to submit a REST query
- The variable, $es, should point to your Elasticsearch instance with <hosname>:<port>
- The variable, $cdm_ver, should match the CDM version you are currently using, and the indices you have created should also have that string in their names.

If you do not already have a run.id, you can get a list of them.  In the example below, we query on run.harness, but you may want to include other terms in your query, like run.tags, run.user, etc.

<pre>
curl -X GET "$es/cdm${cdm_ver}-run/run/_search" -H 'Content-Type: application/json' -d'
{
  "query" : {
      "bool": {
        "filter": [
          { "term":  { "run.harness_name": "pbench" }}
        ]
      }
    }, "_source": [ "run.id" ]
  }
'
</pre>

In our example, three documents were returned, two with the same run.id and a third with a different run.id.  Run.ids should only be used more than once if the run included multiple parameter-sets:

<pre>
"1607f8de-3cca-427c-a54f-2a196108e61b"
"77daae1b-32d4-4357-b06c-046932f52d2b"
"77daae1b-32d4-4357-b06c-046932f52d2b"
</pre>

We will use the run.id, "1607f8de-3cca-427c-a54f-2a196108e61b" to query for iteration.id as well as the benchmark name and iteration params.

<pre>
curl -X GET "$es/cdm${cdm_ver}-iteration/iteration/_search" -H 'Content-Type: application/json' -d'
{
  "query" : {
      "bool": {
        "filter": [
          { "term":  { "run.id": "1607f8de-3cca-427c-a54f-2a196108e61b" }}
        ]
      }
    }, "_source": [ "run.bench.name", "iteration.id", "iteration.params" ]
  }
'
</pre>

In our example, two iteratoin documents were returned, and both have run.bench.name = "fio", while each document have a different list of iteration.params:

<pre>
"iteration" : {
                  "params" : " --write_hist_log=fio  --log_unix_epoch=1  --time_based=1  --log_hist_msec=10000  --output=fio-result.json  --bs=16k  --write_bw_log=fio  --write_lat_log=fio  --filesize=262144K  --filename=/tmp/fio-tst  --runtime=30s  --log_avg_msec=1000  --output-format=json  --write_iops_log=fio  --rw=read  --clients=perf84,perf36",
                  "id" : "37a6e734-96b1-4664-8cdd-2086e05a73cb"
               }
               
"iteration" : {
                  "params" : " --write_hist_log=fio  --log_unix_epoch=1  --time_based=1  --log_hist_msec=10000  --output=fio-result.json  --bs=16k  --write_bw_log=fio  --write_lat_log=fio  --filesize=262144K  --filename=/tmp/fio-tst  --runtime=30s  --log_avg_msec=1000  --output-format=json  --write_iops_log=fio  --rw=randread  --clients=perf84,perf36",
                  "id" : "86f340d6-ec2b-4b37-8636-051462b722c3"
               }
</pre>

For no particular reason, we will choose the iteraton which used "--rw=randread" in its parameters and query with its iteraton.id to get the samples.  

A sample is a one execution of the benchmark with these parameters.  Multiple samples means this benchmark was executed with the exact same parameters multiple times (samples).  This may be needed because the native benchmark does not provide information like standard deviation, and with multiple samples, this can now be done.

<pre>
curl -X GET "$es/cdm${cdm_ver}-sample/sample/_search" -H 'Content-Type: application/json' -d'
{
  "query" : {
      "bool": {
        "filter": [
          { "term":  { "iteration.id": "37a6e734-96b1-4664-8cdd-2086e05a73cb" }}
        ]
      }
    }, "_source": [ "sample.id", "sample.num" ]
  }
'</pre>

Which returned:

<pre>
"sample" : {
                  "num" : "0",
                  "id" : "d605069b-bb14-408e-9396-b9f000acdd72"
               }
</pre>

In this example, there is only one sample returned, which will make the result calculation a little bit easier.  Later, this document will be updated to show how multi-sample calculation is achieved.

For every sample[-execution], there can be one or more [time-]periods.  Period documents simply tell us what the period is called (period.name), and when the period ocurred (period.begin and period.end).  A requirement for every sample[-execution] is to name the "primary" period, the time period where the measurement takes place.  Other periods may also be included with a sample, for example, a period of time representing a "warm-up" for a benchmark.

There is also only one primary_metric for a iteration and all of its samples.  This is the "one, primary" result that is used with the combination of parameters, and thought of as the most recongnized metric when running the benchmark this way.  There can be many other metrics that are not the "primary", from both the benchmark and tools, and so we want to make sure we are not returing those documents when calculating the benchmark result.  We can, however, use those for addtional information when a user wants to investigate a result.

Once we identify the primary period and primary metric for this sample, we can then query for the metrics and calculate our result.  To query for the primary period and primary metric, we can use:

<pre>
curl -X GET "$es/cdm${cdm_ver}-sample/sample/_search" -H 'Content-Type: application/json' -d'
{
  "query" : {
      "bool": {
        "filter": [
          { "term":  { "sample.id": "d605069b-bb14-408e-9396-b9f000acdd72" }}
        ]
      }
    }, "_source": [ "iteration.primary_metric", "iteration.primary_period" ]
  }
'
</pre>

Which returns:

<pre>
"iteration" : {
                  "primary_period" : "measurement",
                  "primary_metric" : "iops"
               }
</pre>

Now we have all the information to form a query to return all of the metric documents that are for this run, iteration, sample, and period.  However, before we do so, we need to understand how the metric documents should be organized.  Currently, each metric document contains one value, for something like "Megabytes_per_second" or "iops".  Values from mutiple documents are collected to evetually form time-series data, a list where each element contains a value and a timestamp.  However, there may be multiple time-series, because the benchmark might have metrics from multiple clients and servers, or the benchmark might provide metrics for different "sub" jobs or threads.

In order to organize all of these metric documents into one or more evetual data-series, we query for the metric.name_format first.  The name_format serves two purposes (1) to guide us on what to call a data series (2) to help us categorize the metric documents into specific data-series.  With this query we can get the name_format:

TODO: convert to aggregate

<pre>
curl -X GET "$es/cdm${cdm_ver}-metric/metric/_search" -H 'Content-Type: application/json' -d'
{
  "query" : {
      "bool": {
        "filter": [
          { "term":  { "period.id" : "9261504f-ae4d-4f7a-aea7-4450e83579b2" } }, { "term":  { "metric.source": "fio" } }, { "term": {"metric.type": "iops" } }
        ]
      }
    }, "_source": [ "metric.name_format" ]
  }
'
</pre>

Which returns (one per document):

<pre>
"metric" : {
                  "name_format" : "%source%-%type%-%hostname%"
               }
</pre>


The format syntax wraps "%" around any string which is meant to represent a metric field name, such as "metric.hostname".  In order to organize into multiple data-series, we identify these fields that are not "source" or "type", as source is the benchmark name, and type is the primary_metric, and should be exactly the same for a query on a specific period.  So in this example, that leaves "hostanme", or metric.hostname.  This means we may have a data-series for each unique hostname we find in all of these metric documents which have metric.source = fio and metric.type = iops.

To return these documents, we use:

<pre>
curl -X GET "$es/cdm${cdm_ver}-metric/metric/_search" -H 'Content-Type: application/json' -d'
{
  "query" : {
      "bool": {
        "filter": [
          { "term":  { "period.id" : "9261504f-ae4d-4f7a-aea7-4450e83579b2" } }, { "term":  { "metric.source": "fio" } }, { "term": {"metric.type": "iops" } }
        ]
      }
    }, "_source": [ "metric.hostname", "metric.value", "metric.begin", "metric.end" ]
  }
'
</pre>

Which returns several documents which contain contents like:

<pre>
"metric" : {
                  "value" : "3824",
                  "begin" : 1549048098418,
                  "hostname" : "perf84",
                  "end" : "1549048099417"
               }
</pre>

and

<pre>
"metric" : {
                  "value" : "151552",
                  "begin" : 1549048113363,
                  "hostname" : "perf36",
                  "end" : "1549048114362"
               }
</pre>



This document is not complete.  Remaining items include:
- organizing the returned metric docs into lists with common values for fields in name_format
- converting these documents to time-series data with common timestamps
- creating an aggrgeate time-series which represents either the summation or average or (some other math function like percentile).
- calculating the average value of the aggregate time-series and returning as the result for this sample.
