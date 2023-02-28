# VPN remote access

**The names of internal products and tools are hidden, only the basic information is present**

**This material is not an example of a testing methodology, but only shows the tools used and the approach to solving the problem!**

# Content
- [VPN remote access](#vpn-remote-access)
- [Content](#content)
- [The scheme of the stand](#the-scheme-of-the-stand)
  - [Description of the components of the stand](#description-of-the-components-of-the-stand)
    - [Configuring a test environment](#configuring-a-test-environment)
  - [Description of interaction](#description-of-interaction)
- [Configuration files](#configuration-files)
  - [YandexTank с Phantom](#yandextank-с-phantom)
    - [TAPs](#taps)
    - [Wget](#wget)
    - [Additional Commands](#additional-commands)
- [Test Description](#test-description)
- [Monitoring](#monitoring)
  - [Description of monitoring tools](#description-of-monitoring-tools)
  - [Description of resource monitoring](#description-of-resource-monitoring)
- [Report](#report)

# The scheme of the stand
![DUT](https://github.com/l-SK-l/My_testing_projects/blob/main/VPN%20remote%20access%20(ENG)/assets/VPN.png)

## Description of the components of the stand
Describes the scheme of the stand with brief explanations of each element

### Configuring a test environment
Described: 
- Physical machine settings
- VPN GW configuration describing important settings
- Network configuration

## Description of interaction
On the load machine scripts are running TAPs (elephants) that dynamically raise VPN tunnels with GOST encryption for each virtual user, connecting, the user starts making requests to an empty page from Nginx, thereby controlling its successful operation. The main purpose of testing is to find the maximum number of users for a particular hardware and software platform, performance testing, stability testing and stress testing. A separate VM with Win\Unix user is used to test the functionality, debugging, performance testing of individual client applications and visual assessment of remote access in different VPN modes.

# Configuration files
All configuration files are found on the VM Ansible\InfluxDB and are automatically deployed with Ansible to each load machine before running each command.

The test is run with variables without the need to edit the configuration files via the ansible `-extra-vars` or `-e` key.

## YandexTank с Phantom
Specifies file locations, Ansible commands to start and stop the test

yandex_tank_config.j2 #Edit each group

```
phantom: #Default traffic generator
  enabled: true  
  address: "{{ addr }}:80" #Web server address
  uris: #File path
  - /{ file }}.html
  phantom_http_entity: 20000M #Max size of the downloaded file
  load_profile: #Profile load
    load_type: #Users
    schedule: line(1,{{ line }},{{ line_time }}) const({{ const }},{{ const_time }}) #Load schedule for users
rcheck: #Check for free resources for the generator
  enabled: true
  mem_limit: 200 #Minimum amount of free memory to work
console: #Console: #Console display at runtime
  enabled: false
telegraf: #Transmitting data to telegraf for monitoring
  enabled: false
```
### TAPs
Specifies the location of the files, the Ansible commands to start and stop the test

run_taps.yaml #Edit each group
```
- hosts: xxx
  vars:
   vpn_address: {{ vpn_addr }}  # VPN_GW address
   pool_mask: {{ vpn_mask }}  #Address pool mask in vpn_addr settings
   connections_per_user: {{ user }} #Number of connections established for each load VM
   connections_per_moment: {{ user_per_mom }}  #Number of connections set up simultaneously
   connections_per_second: {{ user_per_sec }}  #Number of connections per second
```
### Wget
Specifies file locations, Ansible commands to start and stop the test

Additional scripts to measure performance
```
vars:
  srv_address: {{ srv_addr }} #Web server address
  conn_num: {{ conn_num }} #Number of connections from each load machine
  websrv_file: {{ web_file }} #Loadable file
  limit_rate: 285k #Limit the download speed for each connection
```
### Additional Commands
Specifies additional commands Ansible, shutdown/reboot the stand, clear logs, etc.

# Test Description

Describes each test step by step with the action and expected result

# Monitoring

## Description of monitoring tools
To monitor hardware platforms and virtual machines, tools and utilities included in the operating system are used. 
For Unix-like operating systems such utilities are top, htop, vmstat, nload

To collect performance characteristics of the system components the following monitoring tools are supposed to be used:
- SNMP
- Telegraf
- Grafana+InfluxDB

We recommend netstat, ss, tcptrack, sysstat as helper tools.
A brief description of the tools is available in a separate wiki article

## Description of resource monitoring
The following nodes are monitored during testing:
- VPN GW
- Load machines
- Web Server

Data from VPN GW is taken with SMNP (or telegraf if additional metrics are needed), from load machines and Web Server with telegraf. All data are collected in a single monitoring (Grafana+InfluxDB). 

In the process of testing, logs are taken at 30-second intervals for hardware resource usage

For VPN GW including
Processor:
- CPU utilization (including individual processes)
- Average CPU load for 1, 5 and 15 minutes

RAM:
- RAM utilization (including individual processes)

Network:
- Status of interfaces
- Interface Utilization

Disk System:
- Average disk load for 1, 5, and 15 minutes as a percentage
- Partition Status of /, /var, /etc

Other:
- Total uptime.
- Number of clients connected to the VPN
- FW statistics

For Load machines and Web server from the main: CPU utilization, RAM, network interfaces, as well as the number of active connections and vorkers on the Web server and their status.

# Report

The file assumes a structured description of the test bench and summary results in the header of the document, as well as a free description of the tests with explanations, if required by the results 

The header, test bench composition, component versions, test bench settings and test dates must be recorded in the report

Measurement results should be entered after each test into the summary table in the report header
