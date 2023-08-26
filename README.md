# NPS-Log-Visualizer
## Parser and visualization tool for Microsoft NPS / RADIUS logs  
### Installation
1. Download the latest release .ZIP file.
2. Right-click the downloaded file, click Properties, and click "Unblock"
3. Extract the .ZIP to a single directory.
4. Get InfluxDB 1.8 (https://dl.influxdata.com/influxdb/releases/influxdb-1.8.10_windows_amd64.zip)  
    - Unpack the files, place them into an appropriate folder within the Program Files directory  
    - Copy the starter configuration file from this repo into the folder, overwriting the existing file  
    - Start InfluxDB: ```influxd.exe -config .\influxdb.conf```  
5. Get Grafana (https://grafana.com/grafana/download/10.0.3?edition=oss&pg=oss-graf&plcmt=hero-btn-1&platform=windows)
    - Once installed, start Grafana and load [http://localhost:3000](http://localhost:3000)  
NOTE: Because neither InfluxDB or Grafana implements "ServiceMain" in their compiled code, you need to use a wrapper to create a Windows service.  
  - NSSM is recommended (https://nssm.cc/download)
  - You can accomplish similar with non-interactive scheduled tasks if desired.  
### Execution
- On first run, you will likely want to backfill data from logs currently in place on the NPS server.
  - To do this, execute: ```ParseNPSLogs.ps1 $true```  
- On subsequent runs, simply execute ParseNPSLogs.ps1  
- If the parser has not run for some period of time, you can catch up by again running the backfill command.  
### Reference
- Microsoft NPS log format (https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-r2-and-2008/cc771748(v=ws.10))
