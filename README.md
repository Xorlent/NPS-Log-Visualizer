# NPS-Log-Visualizer
## NOTE: Work in progress
Parser and visualization tool for Microsoft NPS / RADIUS logs  
### Installation
- Requires InfluxDB 1.8 (https://dl.influxdata.com/influxdb/releases/influxdb-1.8.10_windows_amd64.zip)  
- Requires Grafana (https://grafana.com/grafana/download/10.0.3?edition=oss&pg=oss-graf&plcmt=hero-btn-1&platform=windows)  
- Because neither InfluxDB or Grafana implements "ServiceMain" in their compiled code, you need to use a wrapper to create a Windows service.  
  - NSSM is recommended (https://nssm.cc/download)
  - You can accomplish similar with non-interactive scheduled tasks if desired.  
### Execution
- On first run, you will likely want to backfill data from logs currently in place on the NPS server.
  - To do this, execute: ```ParseNPSLogs.ps1 $true```  
- On subsequent runs, simply execute ParseNPSLogs.ps1  
- If the parser has not run for some period of time, you can catch up by again running the backfill command.  
### Tested
- Log fetch
- Parser
- Backfill
- Payload generation
- UDP record submission to InfluxDB
- Grafana dashboard alpha
- XML configuration file
### To-do
- Comment script / theory of op
- Rebuild grafana dashboard

### Reference
- Microsoft NPS log format (https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-r2-and-2008/cc771748(v=ws.10))
