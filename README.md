# CommonDataModel
A reference for elastic search indices to unify data for monitoring and benchmarking
## Introduction
### What's The Problem?
Our Data is the problem.  When it comes to performance benchmarking, or just monitoring performance, we have a data compatibility problem.  We don't have a good standard to describe our environment and include performance characterization together.  When we don't have this, many of the solutions created to help us visualize, investigate, and identify performance issues are incompatible with each other.  Solutions are often designed with very specific envornments and cannot be reused for other environments.
### How Can We Fix This?
We can define a common way to store information about our environment, our performance tests (if any), and metrics and events we collect.  Having a common way to process this information allows us to query, summarize, and vizualize performance data across many situations, from comparing compiler performance to identifying bottlenecks in large cloud deployments.
### What This Repository Will Include
We want to provide enough information so that anyone can start storing and querying this data in a common way.  We aim to provide the following:
* a schema for the documents stored in Elastic Search
* a description for each of the documents' field names and their use cases
* an example of taking data from a benchmark execution and creating and importing these documents
* with the example benhcmark execution, example queries to report, summarize, and visualize data
## Directory/Layout
<pre>./templates</pre>
This is where all ES templates will reside, ready for emitting to ES
<pre>./descriptions</pre>
This includes more detailed descriptions for each document-type
<pre>./examples/documents/pbench/fio</pre>
A complete set of documents that were crated by running fio with pbench harness (also includes iostat data)
<pre>./examples/queries</pre>
Example queries against the fio data
<pre>./HOWTO/porting-a-benchmark</pre>
Detailed instructions on how a run of a benchmark can be captured with the various documents
<pre>./HOWTO/porting-a-tool</pre>
Detailed instructions on how a tool's output can be captured with various documents
## Versioning
The common data model will be versioned, and for each version, the number of document-types and their field-names may change.  In general, newer versions will atempt to include all document-types and field-names of previous versions.  The version number is represented in whole numbers, with a git branch for each.  Once a new version is established, only minor fixes should be applied to that version, whth no changes to the schema.  If there is a major problem with a version, it should be marked as non-functional.  As new versions are developed, a branch named <version>-staging will be created, and once the version is complete and tested, the new <version> branch will be created.
## Contributing
## Using Example Data
  Instructions on how to import the included example data into your own Elastic Search instance
