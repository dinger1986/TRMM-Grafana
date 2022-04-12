# TRMM-Grafana Setup methods:
###

## [Baremetal](#trmm-grafana-basic-baremetal-setup)

## [Docker](#docker-setup)

###
# Dashboard Info:
###

## [Current Dashboards](#current-dashboards-1)

## [Updating Dashboards](#updating-dashboards-1)

## [Dashboard Images and Links](#dashboard-images-and-links-1)

###
# TRMM-Grafana Basic baremetal setup:
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
10. Go to dashboards and copy the dashboard to reconfigure how you want it or keep it as default.
11. Verify T-RMM PostgreSQL datasource has the name TacticalRMM, case sensitive. If not, change it to TacticalRMM if you get datasource errors. Updated dashboards no longer require it to be the default datasource. See image below.

![Screenshot 2022-04-06 114312-1](https://user-images.githubusercontent.com/24654529/162878388-38c42632-f4b8-487c-b8c8-2e79ffe7f984.png)

12. Edit the TacticalURL and GrafanaURL variables (if present) in the Agent and Client Dashboards to match your T-RMM and Grafana URLs, then reload the dashboards.

![Screenshot 2022-04-12 135410](https://user-images.githubusercontent.com/24654529/163033682-522642e2-2bda-434d-a917-bd1b6f19c684.png)
##
Add URL action to Tactical (correct URL will be shown at the end of the script):
https://rmm.mydomain.com:3000/d/pLkA1-inz/t-rmm-agent-dashboard?orgId=1&var-Client={{client.name}}&var-Sites={{site.name}}&var-Agent={{agent.hostname}}

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
4. sudo -u postgres psql tacticalrmm -c "ALTER USER dbreader WITH PASSWORD 'new_password';"

If you have errors on some parts of the Dash but the agent count is working you must select an Agent from the top dropdown. This is by design!

1. Go along the top
2. Find Agent and select one from the dropdown

Reset Passwords:
From command line do: `grafana-cli admin reset-admin-password admin`

##

###
# Docker setup:
###

**Assumes existing and in use Tactical and Prometheus/Grafana stacks via docker-compose/Portainer.**

**Network names in the compose files need to be edited to suit your install.**

##
### Edit Tactical docker-compose to specify postgres IP address

```text
networks:
  api-db:
    ipv4_address: ${POSTGRES_IP}
```
Either assign the IP manually to what it is currently assigned or use an env variable.

##
### Edit Grafana docker-compose to add tacticalrmm_api-db network

Under network definitions add tacticalrmm_api-db network:
```text
tacticalrmm_api-db:
  external: true
```
In the grafana service definition ensure IP address is assigned to Grafana and add the tacticalrmm_api-db network:
```text
networks:
  monitor-net:
    ipv4_address: ${GRAFANA_IP}
  tacticalrmm_api-db:
```
##
### Create a read-only PostgreSQL user for the tacticalrmm database

Log into the Docker host system.

Log into the Docker Postgres container:
```text
sudo docker exec -it trmm-postgres bash
```
Log into tacticalrmm database as tactical:
```text
psql tacticalrmm tactical
```
Run the following commands to add dbreader user, generate and store password for dbreader user before proceeding:
```text
CREATE ROLE dbreader WITH LOGIN PASSWORD 'dbreaderpass';
GRANT CONNECT ON DATABASE tacticalrmm TO dbreader;
GRANT USAGE ON SCHEMA public to dbreader;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO dbreader;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO dbreader;
quit
```
Exit container and log off host.
```text
exit
exit
```
##
### Add tacticalrmm data source
Add postgresql data source to Grafana (for now use the tactical user and pass in t-rmm docker-compose config). Edit to suit your configuration, but the Name field MUST be TacticalRMM:

Name: TacticalRMM
Host: postgres-ip:5432
Database: tacticalrmm
User: dbreader
Password: dbreaderpass
Disable TLS/SSL and “Save & test”

![Screenshot 2022-04-06 114312](https://user-images.githubusercontent.com/24654529/162025454-19f4a86d-732b-4d76-b2f8-ad38d07e386d.png)

##
### Add dashboards to Grafana
Open your Grafana instance in your browser.
Begin importing the new dashboards by copying and pasting the json code for each, or downloading the files and importing the jsons directly.

Only use one set of dashboards, you cannot try both sets at the same time without editing the UIDs for one of the sets.
 
**Original Dashboards:**

https://github.com/dinger1986/TRMM-Grafana/blob/main/dashboards/clientmap.json

https://github.com/dinger1986/TRMM-Grafana/blob/main/dashboards/agentdash.json

https://github.com/dinger1986/TRMM-Grafana/blob/main/dashboards/clientdash.json

**Alternate Agent Dashboard:**

https://github.com/dinger1986/TRMM-Grafana/blob/main/alt-trmm-dashboards/agentdash.json

![Screenshot 2022-04-03 102115](https://user-images.githubusercontent.com/24654529/161435055-d0cb80a8-aad9-4baf-9b74-625ab333023e.png)

Leave the UID and names as they are, and import them. Ignore the complaints in my screenshot, I already performed this step.

![Screenshot 2022-04-03 102451](https://user-images.githubusercontent.com/24654529/161435289-9935d9e2-90a1-42fe-b89e-95e91e9dc249.png)

**Important! You must enable cpu, disk, and ram checks for the agents you want to monitor.**

##
### Create a URL action for the TacticalRMM Agent dashboard in TacticalRMM Global Settings, only edit the domain to your grafana domain:

URL Pattern: https://grafana.domain.tld/d/pLkA1-inz/t-rmm-agent-dashboard?orgId=1&var-Client={{client.name}}&var-Sites={{site.name}}&var-Agent={{agent.hostname}}

Now you should be able to select a client and run the URL action to open the Grafana T-RMM Agent dashboard and browse to the others via the embedded links.

## Important
When updating T-RMM Docker images, you'll need to stop the Grafana stack first, as it's tied into the T-RMM network, or the T-RMM stack will not properly stop. After updating, bring up T-RMM first, then Grafana.

##
###
# Current Dashboards
###

**All dashboards have been updated with links to easily switch between them after initial connection to the Agent dashboard, as well as basic Linux agent functionality. Linux info is limited by what data T-RMM currently collects.**

**T-RMM Agent Dashboard** - Used for URL actions and Shows CPU, RAM, Disk usage and other stats for the currently selected PC or PC that URL actions was ran on. Please note for the dashboard to display properly you must have cpu, ram and disk checks on your agents. Also includes most of the functions of the Client Overview dashboard.

**Alternate T-RMM Agent Dashboard** Same as the original, but removes the panels already present in the Client Overview dashboard and adds a small panel that displays the version of the agents installed operating system.

**T-RMM Client Overview Dashboard** - Shows Client, Site, and Agent counts, Information, Warning, and Error counts, as well as messages for them. Links are included for direct access to the associated Grafana Agent Dashboard with agent preselected, as well as to the agents T-RMM page. 

**T-RMM Client Map Dashboard:** 
  * Allows you to display a world map with the position of T-RMM agents.
  
  *To use the client map in Grafana:*
  In T-RMM:
  1. Add customField: Name = "adressPostal" / type Text
  2. Add customField: Name = "geohas" / type Text / Hide Dashboard
  3. Create account for api https://positionstack.com/product
  4. Add python script (and add your api key at line 14) [Download Script](https://raw.githubusercontent.com/dinger1986/TRMM-Grafana/a8e19f8a286cda043d8b06cac9592ee197c2dea2/Scripts/Map_getCoordinates.py)	
  5. Add arguments {{agent.adressPostal}} and {{agent.geohas}} **Warning** The order of the arguments is important!

In Grafana:
  1. Import clientmap.json dash if it's not already in place. Make sure the datasource variable is properly configured, with the same settings as the other two dashboards.

##

# Updating Dashboards

### Baremetal:

1. Swap to user setup for tactical rmm - e.g. su tactical
2. Go to home - cd ~/
3. wget https://raw.githubusercontent.com/dinger1986/TRMM-Grafana/main/updateg.sh
4. chmod +x updateg.sh
5. ./updateg.sh
6. Enter your username
7. Verify T-RMM PostgreSQL datasource has the name TacticalRMM, case sensitive. If not, change it to TacticalRMM or you will get datasource errors.
8. Edit the TacticalURL and GrafanaURL variables (if present) in the Agent and Client Dashboards to match your T-RMM and Grafana URLs, then reload the dashboards.

### Docker:

1. Download the new files from the links in the Docker installation instructions.
2. Import the new dashboards as you did during installation, or import them as new dashboards, changing the UIDs and Names during import. The links between dashboards work via tags, not dashboard name, so you'll be able to use both the original and new dashboards at the same time, to see which you prefer or to transfer panels you added to the previous set to the new ones.
3. Verify T-RMM PostgreSQL datasource has the name TacticalRMM, case sensitive. If not, change it to TacticalRMM or you will get datasource errors.
4. Edit the TacticalURL and GrafanaURL variables (if present) in the Agent and Client Dashboards to match your T-RMM and Grafana URLs, then reload the dashboards.

##

# Dashboard Images and Links

### Agent Dashboard
https://github.com/dinger1986/TRMM-Grafana/blob/main/dashboards/agentdash.json

![Screenshot 2022-04-12 173001](https://user-images.githubusercontent.com/24654529/163067761-4c59b0ca-a74d-4327-934a-536bb945cba8.png)
![Screenshot 2022-04-12 173045](https://user-images.githubusercontent.com/24654529/163066204-ad5379b1-9ced-4c56-ab4e-a69453aa035e.png)

### Alternate Agent Dashboard
https://github.com/dinger1986/TRMM-Grafana/blob/main/alt-trmm-dashboards/agentdash.json

![Screenshot 2022-04-12 175307](https://user-images.githubusercontent.com/24654529/163067694-3e2c2ae4-dbd8-4ee6-a124-da1d736e8a26.png)

### Client Overview Dashboard
https://github.com/dinger1986/TRMM-Grafana/blob/main/dashboards/clientdash.json

![Screenshot 2022-04-12 174723](https://user-images.githubusercontent.com/24654529/163067334-bb8b44be-44c3-4ff0-93cb-1e918b27b7a7.png)

### Client Map Dashboard
https://github.com/dinger1986/TRMM-Grafana/blob/main/dashboards/clientmap.json

![Screenshot 2022-04-12 175718](https://user-images.githubusercontent.com/24654529/163067848-063280b5-6921-4550-bd3c-001175b87cfa.png)
