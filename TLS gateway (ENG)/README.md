# TLS gateway

**The names of internal products and tools are hidden, only the basic information is present**

**This material is not an example of a testing methodology, but only shows the tools used and the approach to solving the problem!**

# Content
- [TLS gateway](#tls-gateway)
- [Content](#content)
- [Configuring the TLS Gateway and Load machines](#configuring-the-tls-gateway-and-load-machines)
- [The scheme of the stand](#the-scheme-of-the-stand)
  - [Description of environment parameters](#description-of-environment-parameters)
    - [TLS gateway](#tls-gateway-1)
  - [Interaction](#interaction)
    - [General description of testing](#general-description-of-testing)
  - [Manage](#manage)
    - [Network](#network)
    - [TLS gateway management machine](#tls-gateway-management-machine)
    - [Grafana Monitoring](#grafana-monitoring)
- [Ansible](#ansible)
  - [Playbooks](#playbooks)
  - [start\_yandex\_tank\_vars.yaml](#start_yandex_tank_varsyaml)
    - [General parameters](#general-parameters)
    - [rm\_tap\_files](#rm_tap_files)
    - [copy\_tap\_files](#copy_tap_files)
    - [start\_tap](#start_tap)
    - [remove\_logs](#remove_logs)
    - [deploy\_load\_TAPS\_Jmeter\_vars](#deploy_load_taps_jmeter_vars)
    - [start\_yandex\_tank\_vars](#start_yandex_tank_vars)
  - [Test Run](#test-run)
- [Tests](#tests)
  - [Without a TLS gateway](#without-a-tls-gateway)
  - [With a TLS gateway](#with-a-tls-gateway)
- [Report](#report)

Several operating modes are presented in the DUT

All modes are tested within a single bench. The bench is selected for the maximum hardware and software platform, for weaker platforms, the bench can be reduced to save virtualization resources.

# Configuring the TLS Gateway and Load machines
By individual manuals.

# The scheme of the stand
![DUT](https://github.com/l-SK-l/My_projects/blob/main/TLS%20%D1%88%D0%BB%D1%8E%D0%B7/assets/DUT.png)

## Description of environment parameters
A description of the VMs specifications and network interfaces, links to a separate article tuning linux for high load.

### TLS gateway
Description of fine-tuning for testing: Licensing, issuing certificates, generating TLS tunnel emulators, network configuration, Telegraf configuration and extra metrics scripts, dashboard configuration in Grafana.

## Interaction
### General description of testing
TLS gateway testing is based on testing web servers with the help of tools located on load machines. Since requests to protected web servers through TLS gateway can be made only through TLS protocol with GOST, emulators are launched on load machines, raising tunnels with TLS gateway over TLS protocol with necessary encryption sets, these tunnels listen to traffic on lo interface with certain ports and redirect requests to tunnel to TLS gateway, and it in its turn to protected resources and back to load machines.
![interaction](https://github.com/l-SK-l/My_projects/blob/main/TLS%20%D1%88%D0%BB%D1%8E%D0%B7/assets/interaction.png)

Yandex-Tank in conjunction with Jmeter is used as a load tool. Yandex-Tank is left because of its ease of collecting metrics, as well as because of the easy debugging in case of problems and external monitoring, if a deeper analysis of the results is needed.

## Manage
### Network
Description of the network part: addressing, network management and monitoring.

### TLS gateway management machine
This VM is designed to manage the TLS gateway through the WEB interface and SSH, describes the procedure for issuing licenses, certificate management and the client with TLS encryption.

### Grafana Monitoring
All hosts of the booth have Telegraf installed, its configuration in the path `/etc/telegraf/telegraf.conf` contains the server InfluxDB and the name of the database in which all metrics are collected.

```
[[outputs.influxdb]]
  # urls = ["http://x.x.x.x:8086"] # CHANGE THIS!
  # database = "xxx" # CHANGE THIS!
```
It describes where in Grafana the external InfluxDB database is specified and how it is specified in Grafana variables.

# Ansible
All tests are managed through the Ansible-playbook on the Test Management Machine **Ansible\InfluxDB**

## Playbooks
Playbooks are located under `/etc/ansible/playbooks` and run from the same directory for convenience.
Let's take a closer look at them:
## start_yandex_tank_vars.yaml

```
---
- hosts: taps
  gather_facts: false
  vars:
    async_value: 21600 #Asynchronous start minute after how many seconds the program will shut down, starttap
    cipher: XXX #Specify a cipher set of several variants
  roles:
    - rm_tap_files
    - copy_tap_files
    - start_tap
- hosts: web-servers
  gather_facts: false
  tasks:      
    - name: remove logs from web server
      command: sh /root/clear_log.sh
- hosts: taps
  gather_facts: true
  roles:
    - remove_logs
    - deploy_load_TAPS_Jmeter_vars #Role to copy configurations of yandex tank and jmeter
    - start_yandex_tank_vars
  vars:
     users: 20000 #Number of users in test per load VM
     rps: 3000 #Number of RPS in test, max and stable per load VM
     time_all: 900 #Total test time, should be equal to the sum of time_step 1 and 2
     time_step_1: 600 #Time to generate results
     time_step_2: 300 #time to hold results
     addr: 127.0.0.1 #Web server address or localhost
     http_port: xxx #Web server or localhost port
     file_name: xxx.html #Requested page from web server
     async_value: 2400 #Time to wait for the whole task to execute
     poll: 0

- hosts: taps
  gather_facts: false
  tasks:
    - pause: seconds=10
    - name: remove logs
      command: sh /root/rm_logs.sh
```
All variables are signed in the comments after #, the variables are needed to make it easier to run the test from the console without editing the values in the file, an example command will be at the very end. 
Let's look at the order and Roles in more detail.
### General parameters

**hosts: taps**
The hosts parameter defines the host group to which the actions below will apply. The hosts file is located at the path `/etc/ansible/hosts` and it lists the addresses of the Load machines in the management network.

**gather_facts: true/false**
A module that collects information about the remote system for the subsequent use of variables, such as hostname or OS version.

**async_value:** 
Asynchronous running commands, after how many seconds the program will shut down if it doesn't end by itself or we don't end it forcibly. Ansible will keep in touch with the host, to control the task.

**vars:**
Variables that will be sent to configuration files before copying them to remote hosts. This parameter can be changed from the console via `-extra-vars` or `-e`, this parameter will have a higher priority than the one specified in the config.

**tasks:** 
Simple tasks, such as executing commands on remote machines.

**roles:**
This is a set of files, tasks, templates, variables, and handlers that together serve a specific purpose. The roles will be discussed in more detail later.

###  rm_tap_files
The task of the current role is to remove the old TAP launch scripts, because the number of scripts can be changed depending on the TLS gateway and the number of physical interfaces.

```
- name: tap_scripts_rm
  shell: rm -rf /root/tap/tap_start*
```
### copy_tap_files
Current role task: Substitute `{{ cipher }}` in the templates of the scripts and copy the TAP startup scripts to the Load machines. The task lists all the startup scripts individually.
**ATTENTION**
In this role, the file `/etc/ansible/roles/copy_tap_files/tasks/maim.yml` lists 16 scripts for 2 physical interfaces, if the test does not need 2 physical interfaces, for example tested not senior platforms, then you should comment out the second half of the config.
The task itself is in abbreviated form:

```
- name: copy tap
  template:
    src: tap_start.j2
    dest: /root/tap/tap_start.sh
    mode: 0777
....
- name: copy tap15
  template:
    src: tap_start15.j2
    dest: /root/tap/tap_start15.sh
    mode: 0777
```
There was a description of scripts emulating TLS tunnels-TAP.

### start_tap
The task of the current role: Run the TAP scripts on the Load machine and log their operation. The log is saved on each Load machine `/root/logs_tap.sh.log`

```
- name: run tap
  shell: ls /root/tap/*.sh | xargs -n 1 -I{} -P666 sh {} > logs_tap.sh.log 2>&1
  args:
    executable: /bin/bash
```
### remove_logs
Current Role Task: Sweeping up various debris on the Loaders

```
- name: Remove logs
  shell: rm -rf /root/wget-log* && rm -rf /root/java_pid* && rm -rf /root/xxx.* && rm -rf /root/xxx.* && rm -rf /root/xxx.* && rm -rf /root/index* && rm -Rfv /root/xxx && rm -Rfv /root/xxx && rm -rf /root/.ansible_async/* && rm -Rfv /root/*.html*
```
### deploy_load_TAPS_Jmeter_vars
The task of the current role: Pass variable values to Jmeter, YandexTank configs and YandexTank startup script, and then distribute the files on the load machines.

```
- name: copy load_TAPS #copy config for jatank to target machines, i.e. elephants
  template:
    src: load_TAPS_Jmeter.j2
    dest: /root/load_TAPS_Jmeter.yaml
- name: copy .jmx #Copy config for Jmeter
  template:
    src: test.j2
    dest: /root/test.jmx
    mode: 0777
- name: copy yatank_script.sh #Copy config to run YandexTank
  template:
    src: yatank_script.j2
    dest: /root/yatank_script.sh
    mode: 0777
```
Script for starting YandexTank

```
#!/bin/bash
time_kill=$(( {{ time_all }} + 300 ))
while true;do
yandex-tank -c /root/load_TAPS_Jmeter.yaml&
sleep $time_kill; 
killall -s SIGINT yandex-tank & killall -9 java & killall -9 tap; 
break; 
done
```
In the startup script, the test time `{{ time_all }}` is also thrown through variables and 300 seconds are added to it to transfer the last metrics (it can be reduced if the test is not heavily loaded), after which, if the test did not end correctly, the processes Yandex-tank, jmeter and tap scripts will be forcibly terminated via kill.
After the test passes, additional time is needed to transfer all metrics, which take a long time to process in high-load tests.

### start_yandex_tank_vars
The task of the current role: Run the test through Yandex-tank and log its operation. The log is saved on each Load machine `/root/logs_script.sh.log

```
- name: start yandex-tank
  shell: sh yatank_script.sh > logs_script.sh.log 2>&1
```

## Test Run
The tests are run from the `/etc/ansible/playbooks` directory, with the command `ansible-playbook start_yandex_tank_vars.yaml -e "users=xxx rps=xxx addr=xxx http_port=xxx file_name=xxx.html cipher=xxx"` where you can specify the necessary parameters in variables without going into separate configs. By default, the test lasts 15 minutes + after 300 seconds all processes will be terminated forcibly!
You can run individual playbooks if needed:

**stop_yandex_tank.yaml** - Stop YandexTank processes

**stop_taps.yaml** - Stop TAP and YandexTank processes

**start_taps.yaml** - Start TAP processes

**start_yandex_tank.yaml** - Start YandexTank processes

**reboot_taps.yaml** - Restart the load machines

# Tests
Describes the order of testing and what you need to pay attention to.

## Without a TLS gateway
These tests are performed solely to make sure that the test environment is "clean" and is not a bottleneck. Tests without TLS gateway should ALWAYS be better than with it!
Run basic tests that show maximum performance and stability. Run before all tests.

## With a TLS gateway
Tests are described in detail, with which ciphers are executed, what is measured with examples of commands and screenshots of results. As an example, one test is described with the steps, the actions of the tester and the expected result.

# Report
Tests must be recorded in the Report.
The report consists of Header, Summary data. Stand Configuration and Test Results.
The Header should contain information about Dates, Version and Executor.
Summary data must contain brief information about test results.
Information about the platform is recorded in the configuration.
In Results, more detailed information about each test is recorded, as follows: 
- A link to the Grafana dashboard, filtered by test time, is present
- A screenshot of the summary results panel is present, showing general information about the test results.
- There are screenshots from the system command line showing the diagnostic commands for certain parts of the system.
- Private settings of the test bench are indicated, if necessary.
- In the case of non-standard behavior, free-form information with attached diagnostic files is entered.

In the case of maximum performance testing, test results are taken at stable load, in the last minutes of the test. 

If errors began to appear earlier, the test is restarted with lower parameters, approximately at the time of the mass occurrence of errors.
