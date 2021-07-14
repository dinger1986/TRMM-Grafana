# TRMM-Grafana Basic setup is:

### 
##### Please note for the dashboard to display properly you must have cpu, ram and disk checks on your agents.
##
1. Swap to user setup for tactical rmm - e.g. su tactical
2. Go to home - cd ~/
3. wget https://raw.githubusercontent.com/dinger1986/TRMM-Grafana/main/installg.sh
4. chmod +x installg.sh
5. ./installg.sh
6. Enter your username
7. Enter the domain for the frontend e.g. rmm.mydomain.com
8. Enter your full domain e.g. mydomain.com
9. Go to https://rmm.mydomain.com:3000
10. Go to dashboards and copy the dashboard to reconfigure how you want it or keep it as default
##
Add URL action to Tactical (correct URL will be shown at the end of the script):
https://rmm.mydomain.com:3000/d/pLkA1-inz/tacticalrmm-dashboard-trmm?orgId=1&var-Client={{client.name}}&var-Sites={{site.name}}&var-Agents_HostName={{agent.hostname}}
##
### Troubleshooting:

If you need to rerun the script the only thing that will need redone is changing the postgres dbreader password 
to the same as is in /etc/grafana/provisioning/datasources/default.yaml

1. To do this type in nano /etc/grafana/provisioning/datasources/default.yaml
2. Copy password under: 
secureJsonData:
  password: ""
3. Replace the password for dbreader for postgres with the following command
4. sudo -u postgres psql tacticalrmm -c "ALTER USER dbreader WITH PASSWORD 'new_password'"

##
### 
### Updating Dashboards (incase theres new ones)
##
1. Swap to user setup for tactical rmm - e.g. su tactical
2. Go to home - cd ~/
3. wget https://raw.githubusercontent.com/dinger1986/TRMM-Grafana/main/updateg.sh
4. chmod +x updateg.sh
5. ./updateg.sh
6. Enter your username
##
