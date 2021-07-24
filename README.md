# TRMM-Grafana Basic setup is:

### 

1. Swap to user setup for tactical rmm - e.g. su tactical
2. Go to home - cd ~/
3. wget https://raw.githubusercontent.com/dinger1986/TRMM-Grafana/main/installg.sh
4. chmod +x installg.sh
5. ./installg.sh
6. Enter your username (the linux user that was used to install tactical, the same user as step 1 hopefully).
7. Enter the domain for the frontend e.g. rmm.mydomain.com
8. Enter your full domain e.g. mydomain.com
9. Go to https://rmm.mydomain.com:3000
10. Go to dashboards and copy the dashboard to reconfigure how you want it or keep it as default
##
Add URL action to Tactical (correct URL will be shown at the end of the script):
https://rmm.mydomain.com:3000/d/pLkA1-inz/tacticalrmm-dashboard-trmm?orgId=1&var-Client={{client.name}}&var-Sites={{site.name}}&var-Agents_HostName={{agent.hostname}}

If you change your dashboard or use a custom one you might need to change the UID for the dashboard from pLkA1-inz to whatever its been changed to.
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

If you have errors on some parts of the Dash but the agent count is working you must select an Agent from the top dropdown. This is by design!

1. Go along the top
2. Find Agents_HostName and select one from the dropdown

##
### 
### Updating Dashboards (incase theres new ones)
### Current Dashboards are one for URL actions and one for TV display

1. Swap to user setup for tactical rmm - e.g. su tactical
2. Go to home - cd ~/
3. wget https://raw.githubusercontent.com/dinger1986/TRMM-Grafana/main/updateg.sh
4. chmod +x updateg.sh
5. ./updateg.sh
6. Enter your username
##

### 
### Current Dashboards

**TacticalRMM dashboard TRMM - Dashboard** used for URL actions and Shows CPU, RAM, Disk usage and other stats for the currently selected PC or PC that URL actions was ran on. Please note for the dashboard to display properly you must have cpu, ram and disk checks on your agents.

**TV Dashboard** - Showing Agent count, information, Errors and Warnings including messages

**TacticalRMM-Dashboard-Map:** 
  * Allows you to display a world map with the position of TRMM agents.
  
  *For use map in Grafana:*  
  In TRMM
  1. Add customField: Name = "adressPostal" / type Text
  2. Add customField: Name = "geohas" / type Text / Hide Dashboard
  3. Create account for api https://positionstack.com/product
  4. add script python (and add you keyAPI at the line 14) [Download Script](https://raw.githubusercontent.com/dinger1986/TRMM-Grafana/a8e19f8a286cda043d8b06cac9592ee197c2dea2/Scripts/Map_getCoordinates.py)	
  5. add arguments {{agent.adressPostal}} and {{agent.geohas}} Warning the order of the arguments is important

In Grafana
  1. add news json in grafana
##
