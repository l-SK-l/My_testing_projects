# SQUID ssl inspection

**The names of internal products and tools are hidden, only the basic information is present**

**This material is not an example of a testing methodology, but only shows the tools used and the approach to solving the problem!**

# Content
- [SQUID ssl inspection](#squid-ssl-inspection)
- [Content](#content)
- [The scheme of the stand](#the-scheme-of-the-stand)
  - [Description of the components of the stand](#description-of-the-components-of-the-stand)
    - [Configuring a test environment](#configuring-a-test-environment)
  - [Description of interaction](#description-of-interaction)
  - [K6](#k6)
    - [Running the test](#running-the-test)
- [Test Description](#test-description)
- [Monitoring](#monitoring)
  - [Description of monitoring tools](#description-of-monitoring-tools)
  - [Description of resource monitoring](#description-of-resource-monitoring)
- [Report](#report)

# The scheme of the stand
![DUT](https://github.com/l-SK-l/My_testing_projects/blob/main/SQUID%20ssl%20inspection%20(ENG)/assets/FW.png)

## Description of the components of the stand
Описывается схема стенда с краткими пояснениям по каждому элементу

### Configuring a test environment
Described: 
- Physical machine settings
- FW configuration describing important settings
- Configuration of the network part

## Description of interaction
Load machine and FW set up external DNS with published A record of the Web server, Load machine requests https page from Web server, FW with Squid intercepts DNS request suitable for the rule, proxies connections by conducting  [MITM](https://ru.wikipedia.org/wiki/%D0%90%D1%82%D0%B0%D0%BA%D0%B0_%D0%BF%D0%BE%D1%81%D1%80%D0%B5%D0%B4%D0%BD%D0%B8%D0%BA%D0%B0) attack by swapping web server certificates with self-signed ones, decrypting traffic and thus performing SSL inspection.
The main performance metric is considered to be Squid's ability to handle new connections per second (CPS\RPS).


## K6
Configure Description

```
import http from 'k6/http';

let all_duration = '600s' //Test Time

export const options = {
    discardResponseBodies: true,
    scenarios: {
        get: {
                executor: 'constant-arrival-rate', //Scenario type
                rate:5000, //RPS
                timeUnit:'1s', //In a second
                duration: all_duration, //test time, taken from the all_duration variable
                preAllocatedVUs: 10, //Users (connections) Minimum
                maxVUs:1000, //Users (connections) Maximum
                exec:'get_func',
                gracefulStop: '0s' //For multiple scripts, first one, second with a delay (startTime:)

        },

        },
    thresholds: { //If a trashhold is triggered, the test will be considered unsuccessful
                'http_req_duration': ['p(95)<300'], //Delays at the 95th percentile not more than 300 ms
        },
};

let webUrl = "https://tst-squid.com/" //URL

export function get_func() {
  http.get(webUrl + 'index.html'); //Page

}
```
### Running the test

Without settings, running script.js
`k6 run script.js` 

Running the script for 30 seconds with 10 users (Parameters can be contained in the script itself)
`k6 run --vus 10 --duration 30s script.js`

Running a script ignoring TLS certificate validation and writing the result to the remote InfluxDB database
`K6 run –insecure-skip-tls-verify –out influxdb=http://100.127.254.86:8060/k6_test script.js`

Running a load scenario with 5 users to 10 in 3 minutes, after that to 10 in 5 minutes, etc.
`k6 run --vus 5 --stage 3m:10,5m:10,10m:35,1m30s:0 script.js`

Running a test with debugging requests http
`k6 run --http-debug=full script.js`

From Docker
`docker run -i loadimpact/k6 run - <script.js`

From Docker to remote influxdb
`docker run -i loadimpact/k6 run -<script.js --out influxdb=http://100.127.254.86:8086/k6_stable_utm`

From Docker to local influxdb
`docker run -i loadimpact/k6 run --out influxdb=http://localhost:8086/myk6db - <script.js`

From Docker-сompose
`docker-compose run k6 run /scripts/ewoks.js`

# Test Description

Before the tests, make sure that the tested environment is functioning properly, the web server is available, when accessing from the load machines to the desired web page is established secure HTTPS connection with TLS1.2, data from all nodes come to the monitoring.

To check the TLS version it is necessary on the web server or a load machine to enable recording of traffic dump from the required interface to the file, from the load machine to download the required page with the command `wget https://tst-squid.com/ --no-check-certificat` , then open the dump and make sure that the secure connection was established with TLS1.2, otherwise you need to adjust the web server settings, specifying the minimum version for ssl encryption 

# Monitoring

## Description of monitoring tools
To monitor hardware platforms and virtual machines, tools and utilities included in the operating system are used. 
For Unix-like operating systems, such utilities are top, htop, vmstat, nload

The following monitoring tools are assumed to collect performance characteristics of the system components:
-	SNMP
-	Telegraf
-	Grafana+InfluxDB

The recommended tools are netstat, ss, tcptrack, sysstat.
A short description of the tools is available in a separate wiki article.

## Description of resource monitoring
The following nodes are monitored during the test:
- FW with Squid
- Load machines
- Web Server

Data from FW with Squid are taken with SMNP (or telegraf if additional metrics are needed), from load machines and Web server with telegraf. All data are collected in a single monitoring (Grafana+InfluxDB).

During testing, logs of hardware resource usage are taken at 30-second intervals

For FW with Squid including
Processor:
- CPU Utilization (including individual processes)
- Average CPU load for 1, 5 and 15 minutes

RAM:
- RAM utilization (including individual processes)

Network:
- Status of interfaces
- Interface Utilization

Disk System:
- Average disk load for 1, 5, and 15 minutes as a percentage
- Partition status of /, /var, /etc

Other:
- Total uptime
- Firewall statistics

For load machines separately:
- Number of requests per second
- Number of threads
- HTTP Codes 
- Net Codes
- Delays by quantiles

# Report

The file assumes a structured description of the bench and summary results in the document header, as well as a free description of the tests with explanations, if required by the results 

The header, test bench composition, component versions, test bench settings and test dates must be recorded in the report
