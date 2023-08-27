# NPS-Log-Visualizer
## Parser and visualization tool for Microsoft NPS / RADIUS logs  
### Installation
#### This procedure assumes everything will be installed on the Microsoft NPS server
1. Download the latest release .ZIP file.
2. Right-click the downloaded file, click Properties, and click "Unblock."
3. Extract the .ZIP to a single directory.
4. Open the NNetwork Policy Server management console and configure "Accounting" options.
    - Configure daily logs in the ODBC format.
    - Restart the NPS service.
5. Get InfluxDB 1.8 (https://dl.influxdata.com/influxdb/releases/influxdb-1.8.10_windows_amd64.zip)  
    - Unpack the files, place them into an appropriate folder within the Program Files directory.  
    - Copy the starter configuration file from this repo into the folder, overwriting the existing file.  
    - Start InfluxDB: ```influxd.exe -config .\influxdb.conf```  
6. Get Grafana (https://grafana.com/grafana/download/10.0.3?edition=oss&pg=oss-graf&plcmt=hero-btn-1&platform=windows)
    - Once installed, start Grafana and load [http://localhost:3000/connections/datasources/new](http://localhost:3000/connections/datasources/new)
    - Select "InfluxDB"  
    - Configure all details as shown [here](https://github.com/Xorlent/NPS-Log-Visualizer/blob/main/InfluxDataSource.jpg)
        - The admin password is blank for a default installation
    - Navigate to [http://localhost:3000/dashboard/import](http://localhost:3000/dashboard/import) and import grafana-dashboard.json from this project.  

NOTE: Because neither InfluxDB or Grafana implements "ServiceMain" in their compiled code, you need to use a wrapper to create a Windows service.  
  - NSSM is recommended (https://nssm.cc/download)
  - You can accomplish similar with non-interactive scheduled tasks if desired.  
### Configuration
#### ParseNPS-Config.xml
- Edit this file to specify your NPS log location, InfluxDB details (if different than the example config provided in this project).  
- If you have a RADIUS test user, specify that username in the "ignoreuser" field.  
### Execution
- On first run, you will likely want to backfill data from logs currently in place on the NPS server.
  - To do this, execute: ```ParseNPSLogs.ps1 $true```
  - Expect execution to take about 1 second for every 10MB of logfile.  If you cancel before the process has completed, it will not save the backfill state.
- On subsequent runs, simply execute ParseNPSLogs.ps1  
- If the parser has not run for some period of time, you can catch up by again running the backfill command.
### Script details
#### ParseNPSLogs.ps1
This is the main program script.  The tool can process about 10MB of log data per second, so plan accordingly if you will be backfilling a large amount of data.  
#### radius_functions.ps1
This file contains lookup functions for various log status fields, converting from numbers to human-readable text  
## Troubleshooting
### I need to backfill data again because my Syslog server was offline/unreachable during the first run
1. Delete the backfilled.txt file
### The script was not running for a few days so I have a gap in logs sent to Syslog
1. Edit backfilled.txt and set the date (in YYMMDD format) to the file prior to where you would like to resume the backfill process.  
2. Run ```NPS-Syslog.ps1 $true```
## Reference
- Microsoft NPS log format (https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-r2-and-2008/cc771748(v=ws.10))
