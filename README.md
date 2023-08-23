# NPS-Log-Visualizer
## NOTE: Work in progress
Parser and visualization tool for Microsoft NPS / RADIUS logs  
### Installation
Requires InfluxDB 1.8 (https://dl.influxdata.com/influxdb/releases/influxdb-1.8.10_windows_amd64.zip)  
Requires Grafana (https://grafana.com/grafana/download/10.0.3?edition=oss&pg=oss-graf&plcmt=hero-btn-1&platform=windows)  
Because neither InfluxDB or Grafana implements "ServiceMain" in their compiled code, you need to use a wrapper to create a Windows service.  NSSM is recommended (https://nssm.cc/download)  
### Tested
- Log fetch
- Parser
- Backfill
- Payload generation
- UDP record submission to InfluxDB
- Grafana dashboard alpha
### To-do
- Comment script / theory of op
- Rebuild grafana dashboard
- Add configuration XML
