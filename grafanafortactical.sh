#!/bin/bash

### Basic setup is are:
##
##
##### Please note for the dashboard to display properly you must have cpu, ram and disk checks on your agents.
##
##
### 1. Swap to user setup for tactical rmm - e.g. su tactical
### 2. Go to home - cd ~/
### 3. wget https://raw.githubusercontent.com/dinger1986/dvis/master/grafanafortactical.sh
### 4. chmod +x grafanafortactical.sh
### 5. ./grafanafortactical.sh
### 6. Enter your username
### 7. Enter the domain for the frontend e.g. rmm.mydomain.com
### 8. Enter your full domain e.g. mydomain.com
### 9. Go to https://rmm.mydomain.com:3000
### 10. Go to dashboards and copy the dashboard to reconfigure how you want it or keep it as default
##
### Add URL action to Tactical (correct URL will be shown at the end of the script):
### https://rmm.mydomain.com:3000/d/pLkA1-inz/tacticalrmm-dashboard-trmm?orgId=1&var-Client={{client.name}}&var-Sites={{site.name}}&var-Agents_HostName={{agent.hostname}}
##
### Troubleshooting:
##
### If you need to rerun the script the only thing that will need redone is changing the postgres dbreader password 
### to the same as is in /etc/grafana/provisioning/datasources/default.yaml
##
### 1. To do this type in nano /etc/grafana/provisioning/datasources/default.yaml
### 2. Copy password under: 
### secureJsonData:
###   password: ""
### 3. Replace the password for dbreader for postgres with the following command
### 4. sudo -u postgres psql tacticalrmm -c "ALTER USER dbreader WITH PASSWORD 'new_password'"

#### Just scripted up to work from @Yasd and @sebcashmag on Discord forum


#check if running on ubuntu 20.04, Debian or Raspbian
osname=$(lsb_release -si); osname=${osname^}
osname=$(echo "$osname" | tr  '[A-Z]' '[a-z]')
fullrel=$(lsb_release -sd)
codename=$(lsb_release -sc)
relno=$(lsb_release -sr | cut -d. -f1)
fullrelno=$(lsb_release -sr)

# Fallback if lsb_release -si returns anything else than Ubuntu, Debian or Raspbian
if [ ! "$osname" = "ubuntu" ] && [ ! "$osname" = "debian" ]; then
  osname=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
  osname=${osname^}
fi


# determine system
if ([ "$osname" = "ubuntu" ] && [ "$fullrelno" = "20.04" ]) || ([ "$osname" = "debian" ] && [ $relno -ge 10 ]); then
  echo $fullrel
else
 echo $fullrel
 echo -ne "${RED}Only Ubuntu release 20.04 and Debian 10 and later, are supported\n"
 echo -ne "Your system does not appear to be supported${NC}\n"
 exit 1
fi

if [ $EUID -eq 0 ]; then
  echo -ne "${RED}Do NOT run this script as root. Exiting.${NC}\n"
  exit 1
fi

#check if running as root
if [ $EUID -eq 0 ]; then
  echo -ne "\033[0;31mDo NOT run this script as root. Exiting.\e[0m\n"
  exit 1
fi

#Username
echo -ne "Enter your created username if you havent done this please do it now, use ctrl+c to cancel this script and do it${NC}: "
read username

while [[ ${domain} != *[.]*[.]* ]]
do
echo -ne "${YELLOW}Enter the main domain setup ie rmm.yourdomain.com ${NC}: "
read domain
done

echo -ne "${YELLOW}Enter the letsencrypt domain (if using txt acme e.g. example.com) or the frontend (as above) (if using certbot dns e.g. rmm.example.com)${NC}: "
read certdomain

admintoken=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 70 | head -n 1)

cd ~/

# Create a read-only PostgreSQL user for the tacticalrmm database
sudo -u postgres psql tacticalrmm -c "CREATE ROLE dbreader WITH LOGIN PASSWORD '${admintoken}'"
sudo -u postgres psql tacticalrmm -c "GRANT CONNECT ON DATABASE tacticalrmm TO dbreader"
sudo -u postgres psql tacticalrmm -c "GRANT USAGE ON SCHEMA public to dbreader"
sudo -u postgres psql tacticalrmm -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO dbreader"
sudo -u postgres psql tacticalrmm -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO dbreader"

# create a firewall rule for the Grafana website (default port is 3000)
sudo ufw allow 3000/tcp
sudo ufw reload

# Install Grafana based on https://grafana.com/docs/grafana/latest/installation/debian/

sudo apt-get install -y apt-transport-https
sudo apt-get install -y software-properties-common wget
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -

# add the repository for the latest stable OSS release
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list

sudo apt-get update
sudo apt-get install grafana

sudo rm /etc/grafana/provisioning/datasources/default.yaml
sudo touch /etc/grafana/provisioning/datasources/default.yaml
sudo chown ${username}:${username} /etc/grafana/provisioning/datasources/default.yaml

#Set Grafana DB file
dbconf="$(cat << EOF
## config file version
apiVersion: 1

## list of datasources that should be deleted from the database
deleteDatasources:

## list of datasources to insert/update depending
datasources:
- name: PostgreSQL
  type: postgres
  access: proxy
  url: localhost:5432
  user: dbreader
  database: tacticalrmm
  basicAuth: false
  isDefault: true
  jsonData:
   postgresVersion: 1200
   sslmode: verify-ca
   tlsAuth: true
   tlsAuthWithCACert: true
   tlsConfigurationMethod: file-path
   tlsSkipVerify: false
  secureJsonData:
   password: "${admintoken}"
  version: 1
  editable: true

EOF
)"
echo "${dbconf}" > /etc/grafana/provisioning/datasources/default.yaml

sudo rm /etc/grafana/provisioning/dashboards/default.yaml
sudo touch /etc/grafana/provisioning/dashboards/default.yaml
sudo chown ${username}:${username} /etc/grafana/provisioning/dashboards/default.yaml

#Set Grafana dashboard file
dashconf="$(cat << EOF

apiVersion: 1

providers:
  - name: Default    # A uniquely identifiable name for the provider
    folder: Tactical # The folder where to place the dashboards
    type: file
    options:
      path: /var/lib/grafana/dashboards

EOF
)"
echo "${dashconf}" > /etc/grafana/provisioning/dashboards/default.yaml

sudo mkdir /var/lib/grafana/dashboards
sudo rm /var/lib/grafana/dashboards/cluster.json
sudo touch /var/lib/grafana/dashboards/cluster.json
sudo chown ${username}:${username} /var/lib/grafana/dashboards/cluster.json

#Set Grafana dashboard layout file
dashlayconf="$(cat << EOF

{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "limit": 100,
        "name": "Annotations & Alerts",
        "type": "dashboard"
      },
      {
        "datasource": null,
        "enable": false,
        "iconColor": "red",
        "name": "Update",
        "rawQuery": "select \n--agents_note.entry_time as \"time\",\nTO_TIMESTAMP((substring(agents_note.note, ('[^le]*\$'))),'YYYY-MM-DD HH24:MI:SS')- INTERVAL '2 hour' as \"time\",\n agents_note.note as \"text\",\n ('Update') as \"tags\"\n--(substring(agents_note.note, ('[^=]*'))) as \"tags\"\nfrom  \n  agents_note\nwhere \n  agents_note.note like 'Update:%' AND\n   agent_id IN (SELECT id FROM agents_agent where agents_agent.description = \$Agents_Description)\n--AND agent_id = 40"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": 10,
  "iteration": 1626210213221,
  "links": [],
  "panels": [
    {
      "collapsed": false,
      "datasource": null,
      "gridPos": {
        "h": 1,
        "w": 24,
        "x": 0,
        "y": 0
      },
      "id": 49,
      "panels": [],
      "title": "Information of the selected agent",
      "type": "row"
    },
    {
      "datasource": null,
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 1,
        "w": 24,
        "x": 0,
        "y": 1
      },
      "id": 57,
      "options": {
        "colorMode": "none",
        "graphMode": "none",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "/.*/",
          "values": true
        },
        "text": {
          "valueSize": 18
        },
        "textMode": "value"
      },
      "pluginVersion": "8.0.5",
      "targets": [
        {
          "format": "table",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "select \n  concat('Site: ',clients_site.name,' / HostName: ', agents_agent.hostname,' ',agents_agent.DESCRIPTION)\nfrom \n  agents_agent\n  LEFT OUTER JOIN clients_site on agents_agent.site_id = clients_site.id\n  where \n    agents_agent.hostname = \$Agents_HostName",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "type": "stat"
    },
    {
      "datasource": null,
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [
            {
              "options": {
                "Connected": {
                  "color": "dark-green",
                  "index": 1
                },
                "No Connected": {
                  "color": "dark-red",
                  "index": 0
                }
              },
              "type": "value"
            },
            {
              "options": {
                "match": "null",
                "result": {
                  "color": "transparent",
                  "index": 2
                }
              },
              "type": "special"
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "transparent",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 1,
        "w": 5,
        "x": 0,
        "y": 2
      },
      "id": 53,
      "options": {
        "colorMode": "background",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [],
          "fields": "/.*/",
          "values": false
        },
        "text": {},
        "textMode": "value"
      },
      "pluginVersion": "8.0.5",
      "targets": [
        {
          "format": "table",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "select   \r\nCASE\r\n  WHEN (count(*) = 1) THEN 'Connected'\r\n  WHEN (count(*) = 0) THEN 'No Connected'\r\n  ELSE ''\r\n END AS modifiedpvc\r\n  \r\n from \r\n  agents_agent\r\n where \r\n   agents_agent.hostname = \$Agents_HostName  and\r\n   last_seen > NOW()- interval '1 hours'\r\n ",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "type": "stat"
    },
    {
      "datasource": null,
      "description": "Track CPU consumption for the selected agent.",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 0,
            "gradientMode": "none",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "lineInterpolation": "smooth",
            "lineStyle": {
              "fill": "solid"
            },
            "lineWidth": 1,
            "pointSize": 5,
            "scaleDistribution": {
              "log": 10,
              "type": "log"
            },
            "showPoints": "always",
            "spanNulls": false,
            "stacking": {
              "group": "A",
              "mode": "normal"
            },
            "thresholdsStyle": {
              "mode": "line+area"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "percentage",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "#EAB839",
                "value": 70
              },
              {
                "color": "dark-red",
                "value": 90
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 11,
        "w": 7,
        "x": 5,
        "y": 2
      },
      "id": 28,
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "hidden",
          "placement": "bottom"
        },
        "tooltip": {
          "mode": "multi"
        }
      },
      "pluginVersion": "8.0.3",
      "targets": [
        {
          "format": "time_series",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "SELECT \r\n  x AS \"time\",\r\n  y as \"CPU Load\"\r\n  FROM checks_checkhistory\r\n  WHERE x BETWEEN '2021-07-01T13:54:25.526Z' AND '2100-07-02T19:54:25.526Z'\r\n  AND check_id IN (SELECT id FROM checks_check WHERE agent_id=(SELECT id FROM agents_agent where agents_agent.hostname = \$Agents_HostName) AND check_type='cpuload')\r\n  ORDER BY x",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "title": "CPU Load Check",
      "type": "timeseries"
    },
    {
      "datasource": null,
      "description": "Track memory consumption for the selected agent.",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 0,
            "gradientMode": "hue",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "lineInterpolation": "smooth",
            "lineWidth": 1,
            "pointSize": 5,
            "scaleDistribution": {
              "log": 10,
              "type": "log"
            },
            "showPoints": "auto",
            "spanNulls": false,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "line+area"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "percentage",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "dark-orange",
                "value": 70
              },
              {
                "color": "dark-red",
                "value": 85
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 11,
        "w": 6,
        "x": 12,
        "y": 2
      },
      "id": 29,
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "hidden",
          "placement": "bottom"
        },
        "tooltip": {
          "mode": "multi"
        }
      },
      "pluginVersion": "8.0.3",
      "targets": [
        {
          "format": "time_series",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "SELECT \r\n  x AS \"time\",\r\n  y as \"Memory Usage\"\r\nFROM \r\n  checks_checkhistory\r\nWHERE \r\n  x BETWEEN '2021-07-01T13:54:25.526Z' AND '2100-07-02T19:54:25.526Z' AND \r\n  check_id IN (SELECT id FROM checks_check WHERE agent_id=(SELECT id FROM agents_agent where agents_agent.hostname = \$Agents_HostName) AND check_type='memory')\r\n  ORDER BY x",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "title": "Memory Usage",
      "type": "timeseries"
    },
    {
      "datasource": null,
      "description": "Track disk consumption for the selected agent.",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 0,
            "gradientMode": "hue",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "lineInterpolation": "smooth",
            "lineStyle": {
              "fill": "solid"
            },
            "lineWidth": 1,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "auto",
            "spanNulls": false,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "line+area"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "percentage",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "dark-red",
                "value": 0.5
              },
              {
                "color": "dark-orange",
                "value": 10
              },
              {
                "color": "green",
                "value": 11
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 11,
        "w": 6,
        "x": 18,
        "y": 2
      },
      "id": 30,
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "hidden",
          "placement": "bottom"
        },
        "tooltip": {
          "mode": "multi"
        }
      },
      "pluginVersion": "8.0.3",
      "targets": [
        {
          "format": "time_series",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "SELECT \r\n  x AS \"time\",\r\n  y as \"Disk Usage\"\r\nFROM \r\n  checks_checkhistory\r\nWHERE \r\n  x BETWEEN '2021-07-01T13:54:25.526Z' AND '2100-07-02T19:54:25.526Z'\r\n  AND check_id IN (SELECT id FROM checks_check WHERE agent_id=(SELECT id FROM agents_agent where agents_agent.hostname = \$Agents_HostName) AND check_type='diskspace')\r\n  ORDER BY x",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "title": "Disk Usage",
      "type": "timeseries"
    },
    {
      "datasource": null,
      "description": "Type of CPU installed",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "text",
                "value": null
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 2,
        "w": 5,
        "x": 0,
        "y": 3
      },
      "id": 50,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [],
          "fields": "/^concat\$/",
          "values": true
        },
        "text": {},
        "textMode": "auto"
      },
      "pluginVersion": "8.0.5",
      "targets": [
        {
          "format": "table",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "select  \r\n  concat(wmi_detail->'cpu'->0->0->>'Name',' \\\ ',wmi_detail->'base_board'->0->0->>'Manufacturer')\r\nfrom \r\n  agents_agent\r\nwhere \r\n   agents_agent.hostname = \$Agents_HostName",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "title": "CPU Name",
      "type": "stat"
    },
    {
      "datasource": null,
      "description": "Agent bone type",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "text",
                "value": null
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 2,
        "w": 5,
        "x": 0,
        "y": 5
      },
      "id": 44,
      "options": {
        "colorMode": "value",
        "graphMode": "none",
        "justifyMode": "center",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "/^concat\$/",
          "values": true
        },
        "text": {},
        "textMode": "value"
      },
      "pluginVersion": "8.0.5",
      "targets": [
        {
          "format": "table",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "select   \r\n  concat(SUBSTRING(agents_agent.operating_system,'(.*),'),' ', wmi_detail->'cpu'->0->0->>'DataWidth',' Bits') \r\n  \r\nfrom \r\n  agents_agent\r\nwhere \r\n     agents_agent.hostname = \$Agents_HostName\r\n",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "type": "stat"
    },
    {
      "datasource": null,
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [
            {
              "options": {
                "Windows not up to date": {
                  "color": "dark-red",
                  "index": 0
                },
                "Windows up to date": {
                  "color": "dark-green",
                  "index": 1
                }
              },
              "type": "value"
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 1,
        "w": 2,
        "x": 0,
        "y": 7
      },
      "id": 59,
      "options": {
        "colorMode": "background",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [],
          "fields": "/.*/",
          "values": true
        },
        "text": {},
        "textMode": "value"
      },
      "pluginVersion": "8.0.5",
      "targets": [
        {
          "format": "table",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "SELECT\n  CASE\n   WHEN (has_patches_pending = true) THEN 'Windows not up to date'\n    WHEN (has_patches_pending = false) THEN 'Windows up to date'\n  ELSE 'nothing'\n END AS  Statut\nFROM \n  agents_agent\nwhere\n     agents_agent.hostname = \$Agents_HostName",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "type": "stat"
    },
    {
      "datasource": null,
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [
            {
              "options": {
                "No reboot required": {
                  "color": "dark-green",
                  "index": 1
                },
                "Reboot required": {
                  "color": "dark-red",
                  "index": 0
                }
              },
              "type": "value"
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 1,
        "w": 2,
        "x": 3,
        "y": 7
      },
      "id": 61,
      "options": {
        "colorMode": "background",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [],
          "fields": "/^statut\$/",
          "values": true
        },
        "text": {},
        "textMode": "value"
      },
      "pluginVersion": "8.0.5",
      "targets": [
        {
          "format": "table",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "select\n  CASE\n   WHEN (agents_agent.needs_reboot = true) THEN 'Reboot required'\n    WHEN (agents_agent.needs_reboot = false) THEN 'No reboot required'\n  ELSE 'nothing'\n END AS  Statut\nFrom \n  agents_agent\nWhere\n  agents_agent.hostname = \$Agents_HostName\n",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "type": "stat"
    },
    {
      "datasource": null,
      "description": "Total Agent Memory",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "text",
                "value": null
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 2,
        "w": 2,
        "x": 0,
        "y": 8
      },
      "id": 39,
      "options": {
        "colorMode": "value",
        "graphMode": "none",
        "justifyMode": "center",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "/.*/",
          "values": true
        },
        "text": {},
        "textMode": "value"
      },
      "pluginVersion": "8.0.5",
      "targets": [
        {
          "format": "table",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "select   \r\n   concat((total_ram),'Gb / ',concat(wmi_detail->'mem'->0->0->>'Speed','Bits'))\r\n  \r\nfrom \r\n  agents_agent\r\nwhere \r\n  agents_agent.hostname = \$Agents_HostName",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "title": "Total_Ram",
      "type": "stat"
    },
    {
      "datasource": null,
      "description": "Total free disk space",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "custom": {
            "align": "auto",
            "displayMode": "auto"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "text",
                "value": null
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 5,
        "w": 3,
        "x": 2,
        "y": 8
      },
      "id": 43,
      "options": {
        "showHeader": false
      },
      "pluginVersion": "8.0.5",
      "targets": [
        {
          "format": "table",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "select \r\n  concat(items.device,'\\\ ', items.free,' free on ',items.total)\r\nfrom \r\n  agents_agent,\r\n  jsonb_to_recordset(disks) as items(device text, free text, total text)\r\nWhere\r\n  agents_agent.hostname = \$Agents_HostName",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "title": "Disk",
      "type": "table"
    },
    {
      "datasource": null,
      "description": "",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "percentage",
            "steps": [
              {
                "color": "dark-green",
                "value": null
              },
              {
                "color": "#EAB839",
                "value": 70
              },
              {
                "color": "dark-red",
                "value": 85
              }
            ]
          },
          "unit": "percent"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 3,
        "w": 2,
        "x": 0,
        "y": 10
      },
      "id": 45,
      "options": {
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [],
          "fields": "/^Occupation\$/",
          "values": false
        },
        "showThresholdLabels": true,
        "showThresholdMarkers": true,
        "text": {}
      },
      "pluginVersion": "8.0.5",
      "targets": [
        {
          "format": "table",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "select\r\n  disks->0->>'percent' as \"Occupation\"\r\nfrom \r\n  agents_agent\r\nwhere \r\n  agents_agent.hostname = \$Agents_HostName\r\n",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "type": "gauge"
    },
    {
      "collapsed": false,
      "datasource": null,
      "gridPos": {
        "h": 1,
        "w": 24,
        "x": 0,
        "y": 13
      },
      "id": 47,
      "panels": [],
      "title": "Information on Client or selected site",
      "type": "row"
    },
    {
      "datasource": null,
      "description": "Number of clients connected to TRMM",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 3,
        "w": 2,
        "x": 0,
        "y": 14
      },
      "id": 31,
      "options": {
        "colorMode": "none",
        "graphMode": "none",
        "justifyMode": "center",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "text": {},
        "textMode": "auto"
      },
      "pluginVersion": "8.0.5",
      "targets": [
        {
          "format": "table",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "SELECT\n  count(*)\nFROM agents_agent\nwhere \n  site_id IN (SELECT id FROM clients_site WHERE site_id IN (SELECT id FROM clients_site WHERE name IN (\$Sites))) and\n  site_id IN (SELECT id FROM clients_site WHERE client_id IN (SELECT id FROM clients_client WHERE name IN (\$Client)))\nORDER BY 1",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "title": "Customer",
      "type": "stat"
    },
    {
      "datasource": null,
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "dark-blue",
                "value": null
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 3,
        "w": 6,
        "x": 2,
        "y": 14
      },
      "id": 24,
      "options": {
        "colorMode": "background",
        "graphMode": "none",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "text": {},
        "textMode": "auto"
      },
      "pluginVersion": "8.0.5",
      "targets": [
        {
          "format": "table",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "SELECT\r\n  count(*)\r\n  FROM alerts_alert\r\nWhere\r\n alerts_alert.severity = 'info' \r\n AND alerts_alert.resolved = false",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "title": "Informations",
      "type": "stat"
    },
    {
      "datasource": null,
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "dark-blue",
                "value": null
              },
              {
                "color": "#EAB839",
                "value": 0
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 3,
        "w": 8,
        "x": 8,
        "y": 14
      },
      "id": 20,
      "options": {
        "colorMode": "background",
        "graphMode": "none",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "text": {},
        "textMode": "auto"
      },
      "pluginVersion": "8.0.5",
      "targets": [
        {
          "format": "table",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "SELECT\r\n  count(*)\r\n  FROM alerts_alert\r\nWhere\r\n alerts_alert.severity = 'warning' \r\n AND alerts_alert.resolved = false",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "title": "Warning",
      "type": "stat"
    },
    {
      "datasource": null,
      "description": "",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 0
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 3,
        "w": 8,
        "x": 16,
        "y": 14
      },
      "id": 23,
      "options": {
        "colorMode": "background",
        "graphMode": "none",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "text": {},
        "textMode": "auto"
      },
      "pluginVersion": "8.0.5",
      "targets": [
        {
          "format": "table",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "SELECT\r\n  count(*) as \"error\"\r\n  FROM alerts_alert\r\nWhere\r\n alerts_alert.severity = 'error'  \r\n AND alerts_alert.resolved = false",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "title": "Error",
      "type": "stat"
    },
    {
      "datasource": null,
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            }
          },
          "mappings": [],
          "unit": "percent"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 5,
        "x": 0,
        "y": 17
      },
      "id": 18,
      "options": {
        "displayLabels": [
          "percent",
          "name"
        ],
        "legend": {
          "displayMode": "hidden",
          "placement": "right",
          "values": [
            "percent"
          ]
        },
        "pieType": "pie",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "tooltip": {
          "mode": "single"
        }
      },
      "pluginVersion": "8.0.3",
      "targets": [
        {
          "format": "table",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "  select (\r\nSELECT\r\n  count(*)\r\n  FROM agents_agent\r\nWhere\r\n  SUBSTRING(agents_agent.operating_system,POSITION(',' in agents_agent.operating_system)+2,2) = '64' and\r\n  site_id IN (SELECT id FROM clients_site WHERE site_id IN (SELECT id FROM clients_site WHERE name IN (\$Sites))) and\r\n  site_id IN (SELECT id FROM clients_site WHERE client_id IN (SELECT id FROM clients_client WHERE name IN (\$Client)))) as \"64 Bits\",\r\n\r\n  (SELECT\r\n  count(*)\r\n  FROM agents_agent\r\nWhere\r\n  SUBSTRING(agents_agent.operating_system,POSITION(',' in agents_agent.operating_system)+2,2) = '32' and\r\n   site_id IN (SELECT id FROM clients_site WHERE site_id IN (SELECT id FROM clients_site WHERE name IN (\$Sites))) and\r\n  site_id IN (SELECT id FROM clients_site WHERE client_id IN (SELECT id FROM clients_client WHERE name IN (\$Client)))) as \"32 Bits\" ",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "title": "OS distribution",
      "type": "piechart"
    },
    {
      "datasource": null,
      "description": "List all Windows installed",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "continuous-GrYlRd"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 17,
        "w": 6,
        "x": 5,
        "y": 17
      },
      "id": 26,
      "options": {
        "displayMode": "gradient",
        "orientation": "horizontal",
        "reduceOptions": {
          "calcs": [
            "last"
          ],
          "fields": "",
          "values": true
        },
        "showUnfilled": true,
        "text": {}
      },
      "pluginVersion": "8.0.5",
      "targets": [
        {
          "format": "table",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "  SELECT \r\n  count(*) as \"count\",\r\n  SUBSTRING(agents_agent.operating_system,'(.*)bit') AS \"Operating System\"\r\n  FROM agents_agent\r\nINNER JOIN clients_site on site_id = clients_site.id\r\n\r\nWHERE site_id IN (SELECT id FROM clients_site WHERE client_id IN (SELECT id FROM clients_client WHERE name IN (\$Client)))\r\nAND site_id IN (SELECT id FROM clients_site WHERE site_id IN (SELECT id FROM clients_site WHERE name IN (\$Sites)))\r\nGroup by \"Operating System\"\r\nOrder by \"count\" desc\r\n  ",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "title": "Windows type",
      "type": "bargauge"
    },
    {
      "datasource": null,
      "description": "List all installed processors",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "continuous-GrYlRd"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 17,
        "w": 7,
        "x": 11,
        "y": 17
      },
      "id": 54,
      "options": {
        "displayMode": "gradient",
        "orientation": "horizontal",
        "reduceOptions": {
          "calcs": [
            "last"
          ],
          "fields": "",
          "values": true
        },
        "showUnfilled": true,
        "text": {}
      },
      "pluginVersion": "8.0.5",
      "targets": [
        {
          "format": "table",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "  SELECT \r\n  count(*) as \"count\",\r\n  wmi_detail->'cpu'->0->0->>'Name' as \"CPU Name\"\r\n  FROM agents_agent\r\nINNER JOIN clients_site on site_id = clients_site.id\r\n\r\nWHERE site_id IN (SELECT id FROM clients_site WHERE client_id IN (SELECT id FROM clients_client WHERE name IN (\$Client)))\r\nAND site_id IN (SELECT id FROM clients_site WHERE site_id IN (SELECT id FROM clients_site WHERE name IN (\$Sites)))\r\nGroup by \"CPU Name\"\r\nOrder by \"count\" desc\r\n  ",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "title": "Processor type",
      "type": "bargauge"
    },
    {
      "datasource": null,
      "description": "List all installed memory",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "continuous-GrYlRd"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 17,
        "w": 6,
        "x": 18,
        "y": 17
      },
      "id": 55,
      "options": {
        "displayMode": "gradient",
        "orientation": "horizontal",
        "reduceOptions": {
          "calcs": [
            "last"
          ],
          "fields": "",
          "values": true
        },
        "showUnfilled": true,
        "text": {}
      },
      "pluginVersion": "8.0.5",
      "targets": [
        {
          "format": "table",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "  SELECT \r\n  count(*) as \"count\",\r\n  concat((total_ram),' Gb') as \"Size Memory\"\r\n  FROM agents_agent\r\nINNER JOIN clients_site on site_id = clients_site.id\r\n\r\nWHERE\r\nAND site_id IN (SELECT id FROM clients_site WHERE client_id IN (SELECT id FROM clients_client WHERE name IN (\$Client)))\r\nAND site_id IN (SELECT id FROM clients_site WHERE site_id IN (SELECT id FROM clients_site WHERE name IN (\$Sites)))\r\nGroup by \"Size Memory\"\r\nOrder by \"count\" desc\r\n  ",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "title": "Memory type",
      "type": "bargauge"
    },
    {
      "datasource": null,
      "description": "Number of clients connected to TRMM",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "custom": {
            "align": "auto",
            "displayMode": "auto"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              }
            ]
          }
        },
        "overrides": [
          {
            "matcher": {
              "id": "byName",
              "options": "Site"
            },
            "properties": [
              {
                "id": "custom.width",
                "value": 79
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "Last Reboot"
            },
            "properties": [
              {
                "id": "custom.width",
                "value": null
              }
            ]
          }
        ]
      },
      "gridPos": {
        "h": 13,
        "w": 9,
        "x": 0,
        "y": 34
      },
      "id": 14,
      "options": {
        "showHeader": true,
        "sortBy": [
          {
            "desc": false,
            "displayName": "Last Reboot"
          }
        ]
      },
      "pluginVersion": "8.0.5",
      "targets": [
        {
          "format": "table",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "SELECT \r\n  clients_site.name AS \"Site\",\r\n  hostname AS \"Hostname\",\r\n  description as \"description\",\r\n  last_seen AS \"Last Response\",\r\n  to_timestamp(boot_time) AS \"Last Reboot\"\r\nFROM agents_agent\r\nINNER JOIN clients_site on site_id = clients_site.id\r\n\r\nWHERE \r\nsite_id IN (SELECT id FROM clients_site WHERE client_id IN (SELECT id FROM clients_client WHERE name IN (\$Client)))\r\nAND site_id IN (SELECT id FROM clients_site WHERE site_id IN (SELECT id FROM clients_site WHERE name IN (\$Sites)))",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "title": "Client last reboot",
      "type": "table"
    },
    {
      "datasource": null,
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "custom": {
            "align": "auto",
            "displayMode": "auto"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": [
          {
            "matcher": {
              "id": "byName",
              "options": "Date Message"
            },
            "properties": [
              {
                "id": "custom.width",
                "value": 185
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "severity"
            },
            "properties": [
              {
                "id": "custom.width",
                "value": 117
              }
            ]
          }
        ]
      },
      "gridPos": {
        "h": 13,
        "w": 15,
        "x": 9,
        "y": 34
      },
      "id": 33,
      "options": {
        "showHeader": true,
        "sortBy": []
      },
      "pluginVersion": "8.0.5",
      "targets": [
        {
          "format": "table",
          "group": [],
          "metricColumn": "none",
          "rawQuery": true,
          "rawSql": "SELECT \r\n  alert_time as \"Date Message\",\r\n  alerts_alert.severity,\r\n  message as \"Messages\"\r\n  FROM alerts_alert\r\nWHERE \r\n alerts_alert.severity = '\$Message_Severity'\r\n AND alerts_alert.resolved = false",
          "refId": "A",
          "select": [
            [
              {
                "params": [
                  "boot_time"
                ],
                "type": "column"
              }
            ]
          ],
          "table": "agents_agent",
          "timeColumn": "last_seen",
          "timeColumnType": "timestamp",
          "where": [
            {
              "name": "\$__timeFilter",
              "params": [],
              "type": "macro"
            }
          ]
        }
      ],
      "title": "Error message",
      "type": "table"
    }
  ],
  "refresh": false,
  "schemaVersion": 30,
  "style": "dark",
  "tags": [],
  "templating": {
    "list": [
      {
        "allValue": null,
        "current": {
          "selected": true,
          "text": [
            "All"
          ],
          "value": [
            "\$__all"
          ]
        },
        "datasource": null,
        "definition": "SELECT name FROM clients_client",
        "description": null,
        "error": null,
        "hide": 0,
        "includeAll": true,
        "label": null,
        "multi": false,
        "name": "Client",
        "options": [],
        "query": "SELECT name FROM clients_client",
        "refresh": 1,
        "regex": "",
        "skipUrlSync": false,
        "sort": 0,
        "tagValuesQuery": "",
        "tagsQuery": "",
        "type": "query",
        "useTags": false
      },
      {
        "allValue": null,
        "current": {
          "selected": false,
          "text": "All",
          "value": "\$__all"
        },
        "datasource": null,
        "definition": "SELECT name FROM clients_site",
        "description": null,
        "error": null,
        "hide": 0,
        "includeAll": true,
        "label": null,
        "multi": false,
        "name": "Sites",
        "options": [],
        "query": "SELECT name FROM clients_site",
        "refresh": 1,
        "regex": "",
        "skipUrlSync": false,
        "sort": 0,
        "type": "query"
      },
      {
        "allValue": null,
        "current": {
          "selected": false,
          "text": "C04-BACALAN",
          "value": "C04-BACALAN"
        },
        "datasource": null,
        "definition": "SELECT \nhostname\nFROM \nagents_agent\n\n\n",
        "description": null,
        "error": null,
        "hide": 0,
        "includeAll": true,
        "label": null,
        "multi": false,
        "name": "Agents_HostName",
        "options": [],
        "query": "SELECT \nhostname\nFROM \nagents_agent\n\n\n",
        "refresh": 1,
        "regex": "",
        "skipUrlSync": false,
        "sort": 1,
        "type": "query"
      },
      {
        "allValue": null,
        "current": {
          "selected": false,
          "text": "error",
          "value": "error"
        },
        "datasource": null,
        "definition": "SELECT \nalerts_alert.severity\n  FROM alerts_alert",
        "description": null,
        "error": null,
        "hide": 0,
        "includeAll": false,
        "label": null,
        "multi": false,
        "name": "Message_Severity",
        "options": [],
        "query": "SELECT \nalerts_alert.severity\n  FROM alerts_alert",
        "refresh": 1,
        "regex": "",
        "skipUrlSync": false,
        "sort": 1,
        "type": "query"
      }
    ]
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {
    "hidden": false
  },
  "timezone": "",
  "title": "TacticalRMM dashboard TRMM",
  "uid": "pLkA1-inz",
  "version": 6
}

EOF
)"
echo "${dashlayconf}" > /var/lib/grafana/dashboards/cluster.json



sudo rm /etc/grafana/grafana.ini
sudo touch /etc/grafana/grafana.ini
sudo chown ${username}:${username} /etc/grafana/grafana.ini

#Set grafana ini config
grafanaini="$(cat << EOF
##################### Grafana Configuration Example #####################
#
# Everything has defaults so you only need to uncomment things you want to
# change

# possible values : production, development
;app_mode = production

# instance name, defaults to HOSTNAME environment variable value or hostname if HOSTNAME var is empty
;instance_name = \${HOSTNAME}

#################################### Paths ####################################
[paths]
# Path to where grafana can store temp files, sessions, and the sqlite3 db (if that is used)
;data = /var/lib/grafana

# Temporary files in `data` directory older than given duration will be removed
;temp_data_lifetime = 24h

# Directory where grafana can store logs
logs = /var/log/grafana

# Directory where grafana will automatically scan and look for plugins
;plugins = /var/lib/grafana/plugins

# folder that contains provisioning config files that grafana will apply on startup and while running.
provisioning = /etc/grafana/provisioning

#################################### Server ####################################
[server]
# Protocol (http, https, h2, socket)
protocol = https

# The ip address to bind to, empty will bind to all interfaces
;http_addr = https://${domain}:3000

# The http port  to use
;http_port = 3000

# The public facing domain name used to access grafana from a browser
domain = ${domain}

# Redirect to correct domain if host header does not match domain
# Prevents DNS rebinding attacks
;enforce_domain = false

# The full public facing url you use in browser, used for redirects and emails
# If you use reverse proxy and sub path specify full url (with sub path)
;root_url = %(protocol)s://%(domain)s:%(http_port)s/

# Serve Grafana from subpath specified in `root_url` setting. By default it is set to `false` for compatibility reasons.
;serve_from_sub_path = false

# Log web requests
;router_logging = false

# the path relative working path
;static_root_path = public

# enable gzip
;enable_gzip = false
# https certs & key file
cert_file = /etc/letsencrypt/live/${certdomain}/fullchain.pem
cert_key = /etc/letsencrypt/live/${certdomain}/privkey.pem

# Unix socket path
;socket =

# CDN Url
;cdn_url =

# Sets the maximum time using a duration format (5s/5m/5ms) before timing out read of an incoming request and closing i>
# `0` means there is no timeout for reading the request.
;read_timeout = 0

#################################### Database ####################################
[database]
# You can configure the database connection by specifying type, host, name, user and password
# as separate properties or as on string using the url properties.

# Either "mysql", "postgres" or "sqlite3", it's your choice
;type = sqlite3
;host = 127.0.0.1:3306
;name = grafana
;user = root
# If the password contains # or ; you have to wrap it with triple quotes. Ex """#password;"""
;password =

# Use either URL or the previous fields to configure the database
# Example: mysql://user:secret@host:port/database
;url =

# For "postgres" only, either "disable", "require" or "verify-full"
;ssl_mode = disable

# Database drivers may support different transaction isolation levels.
# Currently, only "mysql" driver supports isolation levels.
# If the value is empty - driver's default isolation level is applied.
# For "mysql" use "READ-UNCOMMITTED", "READ-COMMITTED", "REPEATABLE-READ" or "SERIALIZABLE".
;isolation_level =

;ca_cert_path =
;client_key_path =
;client_cert_path =
;server_cert_name =

# For "sqlite3" only, path relative to data_path setting
;path = grafana.db

# Max idle conn setting default is 2
;max_idle_conn = 2

# Max conn setting default is 0 (mean not set)
;max_open_conn =

# Connection Max Lifetime default is 14400 (means 14400 seconds or 4 hours)
;conn_max_lifetime = 14400

# Set to true to log the sql calls and execution times.
;log_queries =

# For "sqlite3" only. cache mode setting used for connecting to the database. (private, shared)
;cache_mode = private

################################### Data sources #########################
[datasources]
# Upper limit of data sources that Grafana will return. This limit is a temporary configuration and it will be deprecat>
;datasource_limit = 5000

#################################### Cache server #############################
[remote_cache]
# Either "redis", "memcached" or "database" default is "database"
;type = database

# cache connectionstring options
# database: will use Grafana primary database.
# redis: config like redis server e.g. `addr=127.0.0.1:6379,pool_size=100,db=0,ssl=false`. Only addr is required. ssl m>
# memcache: 127.0.0.1:11211
;connstr =

#################################### Data proxy ###########################
[dataproxy]

# This enables data proxy logging, default is false
;logging = false

# How long the data proxy waits before timing out, default is 30 seconds.
# This setting also applies to core backend HTTP data sources where query requests use an HTTP client with timeout set.
;timeout = 30

# How many seconds the data proxy waits before sending a keepalive probe request.
;keep_alive_seconds = 30

# How many seconds the data proxy waits for a successful TLS Handshake before timing out.
;tls_handshake_timeout_seconds = 10

# How many seconds the data proxy will wait for a server's first response headers after
# fully writing the request headers if the request has an "Expect: 100-continue"
# header. A value of 0 will result in the body being sent immediately, without
# waiting for the server to approve.
;expect_continue_timeout_seconds = 1

# The maximum number of idle connections that Grafana will keep alive.
;max_idle_connections = 100

# How many seconds the data proxy keeps an idle connection open before timing out.
;idle_conn_timeout_seconds = 90

# If enabled and user is not anonymous, data proxy will add X-Grafana-User header with username into the request, defau>
;send_user_header = false

#################################### Analytics ####################################
[analytics]
# Server reporting, sends usage counters to stats.grafana.org every 24 hours.
# No ip addresses are being tracked, only simple counters to track
# running instances, dashboard and error counts. It is very helpful to us.
# Change this option to false to disable reporting.
;reporting_enabled = true

# The name of the distributor of the Grafana instance. Ex hosted-grafana, grafana-labs
;reporting_distributor = grafana-labs

# Set to false to disable all checks to https://grafana.net
# for new versions (grafana itself and plugins), check is used
# in some UI views to notify that grafana or plugin update exists
# This option does not cause any auto updates, nor send any information
# only a GET request to http://grafana.com to get latest versions
;check_for_updates = true

# Google Analytics universal tracking code, only enabled if you specify an id here
;google_analytics_ua_id =

# Google Tag Manager ID, only enabled if you specify an id here
;google_tag_manager_id =

#################################### Security ####################################
[security]
# disable creation of admin user on first start of grafana
;disable_initial_admin_creation = false

# default admin user, created on startup
;admin_user = admin

# default admin password, can be changed before first start of grafana,  or in profile settings
;admin_password = admin

# used for signing
;secret_key = SW2YcwTIb9zpOOhoPsMm

# disable gravatar profile images
;disable_gravatar = false

# data source proxy whitelist (ip_or_domain:port separated by spaces)
;data_source_proxy_whitelist =
# disable protection against brute force login attempts
;disable_brute_force_login_protection = false

# set to true if you host Grafana behind HTTPS. default is false.
;cookie_secure = false

# set cookie SameSite attribute. defaults to `lax`. can be set to "lax", "strict", "none" and "disabled"
;cookie_samesite = lax

# set to true if you want to allow browsers to render Grafana in a <frame>, <iframe>, <embed> or <object>. default is f>
;allow_embedding = false

# Set to true if you want to enable http strict transport security (HSTS) response header.
# This is only sent when HTTPS is enabled in this configuration.
# HSTS tells browsers that the site should only be accessed using HTTPS.
;strict_transport_security = false

# Sets how long a browser should cache HSTS. Only applied if strict_transport_security is enabled.
;strict_transport_security_max_age_seconds = 86400

# Set to true if to enable HSTS preloading option. Only applied if strict_transport_security is enabled.
;strict_transport_security_preload = false

# Set to true if to enable the HSTS includeSubDomains option. Only applied if strict_transport_security is enabled.
;strict_transport_security_subdomains = false

# Set to true to enable the X-Content-Type-Options response header.
# The X-Content-Type-Options response HTTP header is a marker used by the server to indicate that the MIME types advert>
# in the Content-Type headers should not be changed and be followed.
;x_content_type_options = true

# Set to true to enable the X-XSS-Protection header, which tells browsers to stop pages from loading
# when they detect reflected cross-site scripting (XSS) attacks.
;x_xss_protection = true

# Enable adding the Content-Security-Policy header to your requests.
# CSP allows to control resources the user agent is allowed to load and helps prevent XSS attacks.
;content_security_policy = false

# Set Content Security Policy template used when adding the Content-Security-Policy header to your requests.
# $NONCE in the template includes a random nonce.
;content_security_policy_template = """script-src 'unsafe-eval' 'strict-dynamic' $NONCE;object-src 'none';font-src 'sel>

#################################### Snapshots ###########################
[snapshots]
# snapshot sharing options
;external_enabled = true
;external_snapshot_url = https://snapshots-origin.raintank.io
;external_snapshot_name = Publish to snapshot.raintank.io

# Set to true to enable this Grafana instance act as an external snapshot server and allow unauthenticated requests for
# creating and deleting snapshots.
;public_mode = false

# remove expired snapshot
;snapshot_remove_expired = true

#################################### Dashboards History ##################
[dashboards]
# Number dashboard versions to keep (per dashboard). Default: 20, Minimum: 1
;versions_to_keep = 20
# Minimum dashboard refresh interval. When set, this will restrict users to set the refresh interval of a dashboard low>
# The interval string is a possibly signed sequence of decimal numbers, followed by a unit suffix (ms, s, m, h, d), e.g>
;min_refresh_interval = 5s

# Path to the default home dashboard. If this value is empty, then Grafana uses StaticRootPath + "dashboards/home.json"
;default_home_dashboard_path =

#################################### Users ###############################
[users]
# disable user signup / registration
;allow_sign_up = true

# Allow non admin users to create organizations
;allow_org_create = true

# Set to true to automatically assign new users to the default organization (id 1)
;auto_assign_org = true

# Set this value to automatically add new users to the provided organization (if auto_assign_org above is set to true)
;auto_assign_org_id = 1

# Default role new users will be automatically assigned (if disabled above is set to true)
;auto_assign_org_role = Viewer

# Require email validation before sign up completes
;verify_email_enabled = false

# Background text for the user field on the login page
;login_hint = email or username
;password_hint = password
# Default UI theme ("dark" or "light")
;default_theme = dark

# Path to a custom home page. Users are only redirected to this if the default home dashboard is used. It should match >
; home_page =

# External user management, these options affect the organization users view
;external_manage_link_url =
;external_manage_link_name =
;external_manage_info =

# Viewers can edit/inspect dashboard settings in the browser. But not save the dashboard.
;viewers_can_edit = false

# Editors can administrate dashboard, folders and teams they create
;editors_can_admin = false

# The duration in time a user invitation remains valid before expiring. This setting should be expressed as a duration.>
;user_invite_max_lifetime_duration = 24h

# Enter a comma-separated list of users login to hide them in the Grafana UI. These users are shown to Grafana admins a>
; hidden_users =

[auth]
# Login cookie name
;login_cookie_name = grafana_session

# The maximum lifetime (duration) an authenticated user can be inactive before being required to login at next visit. D>
;login_maximum_inactive_lifetime_duration =
# The maximum lifetime (duration) an authenticated user can be logged in since login time before being required to logi>
;login_maximum_lifetime_duration =

# How often should auth tokens be rotated for authenticated users when being active. The default is each 10 minutes.
;token_rotation_interval_minutes = 10

# Set to true to disable (hide) the login form, useful if you use OAuth, defaults to false
;disable_login_form = false

# Set to true to disable the signout link in the side menu. useful if you use auth.proxy, defaults to false
;disable_signout_menu = false

# URL to redirect the user to after sign out
;signout_redirect_url =

# Set to true to attempt login with OAuth automatically, skipping the login screen.
# This setting is ignored if multiple OAuth providers are configured.
;oauth_auto_login = false

# OAuth state max age cookie duration in seconds. Defaults to 600 seconds.
;oauth_state_cookie_max_age = 600

# limit of api_key seconds to live before expiration
;api_key_max_seconds_to_live = -1

# Set to true to enable SigV4 authentication option for HTTP-based datasources.
;sigv4_auth_enabled = false

#################################### Anonymous Auth ######################
[auth.anonymous]
# enable anonymous access
;enabled = false

# specify organization name that should be used for unauthenticated users
;org_name = Main Org.

# specify role for unauthenticated users
;org_role = Viewer

# mask the Grafana version number for unauthenticated users
;hide_version = false

#################################### GitHub Auth ##########################
[auth.github]
;enabled = false
;allow_sign_up = true
;client_id = some_id
;client_secret = some_secret
;scopes = user:email,read:org
;auth_url = https://github.com/login/oauth/authorize
;token_url = https://github.com/login/oauth/access_token
;api_url = https://api.github.com/user
;allowed_domains =
;team_ids =
;allowed_organizations =

#################################### GitLab Auth #########################
[auth.gitlab]
;enabled = false
;allow_sign_up = true
;client_id = some_id
;client_secret = some_secret
;scopes = api
;auth_url = https://gitlab.com/oauth/authorize
;token_url = https://gitlab.com/oauth/token
;api_url = https://gitlab.com/api/v4
;allowed_domains =
;allowed_groups =

#################################### Google Auth ##########################
[auth.google]
;enabled = false
;allow_sign_up = true
;client_id = some_client_id
;client_secret = some_client_secret
;scopes = https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email
;auth_url = https://accounts.google.com/o/oauth2/auth
;token_url = https://accounts.google.com/o/oauth2/token
;api_url = https://www.googleapis.com/oauth2/v1/userinfo
;allowed_domains =
;hosted_domain =

#################################### Grafana.com Auth ####################
[auth.grafana_com]
;enabled = false
;allow_sign_up = true
;client_id = some_id
;client_secret = some_secret
;scopes = user:email
;allowed_organizations =

#################################### Azure AD OAuth #######################
[auth.azuread]
;name = Azure AD
;enabled = false
;allow_sign_up = true
;client_id = some_client_id
;client_secret = some_client_secret
;scopes = openid email profile
;auth_url = https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/authorize
;token_url = https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/token
;allowed_domains =
;allowed_groups =

#################################### Okta OAuth #######################
[auth.okta]
;name = Okta
;enabled = false
;allow_sign_up = true
;client_id = some_id
;client_secret = some_secret
;scopes = openid profile email groups
;auth_url = https://<tenant-id>.okta.com/oauth2/v1/authorize
;token_url = https://<tenant-id>.okta.com/oauth2/v1/token
;api_url = https://<tenant-id>.okta.com/oauth2/v1/userinfo
;allowed_domains =
;allowed_groups =
;role_attribute_path =

#################################### Generic OAuth ##########################
[auth.generic_oauth]
;enabled = false
;name = OAuth
;allow_sign_up = true
;client_id = some_id
;client_secret = some_secret
;scopes = user:email,read:org
;email_attribute_name = email:primary
;email_attribute_path =
;login_attribute_path =
;name_attribute_path =
;id_token_attribute_name =
;auth_url = https://foo.bar/login/oauth/authorize
;token_url = https://foo.bar/login/oauth/access_token
;api_url = https://foo.bar/user
;allowed_domains =
;team_ids =
;allowed_organizations =
;role_attribute_path =
;tls_skip_verify_insecure = false
;tls_client_cert =
;tls_client_key =
;tls_client_ca =

#################################### Basic Auth ##########################
[auth.basic]
;enabled = true

#################################### Auth Proxy ##########################
[auth.proxy]
;enabled = false
;header_name = X-WEBAUTH-USER
;header_property = username
;auto_sign_up = true
;sync_ttl = 60
;whitelist = 192.168.1.1, 192.168.2.1
;headers = Email:X-User-Email, Name:X-User-Name
# Read the auth proxy docs for details on what the setting below enables
;enable_login_token = false

#################################### Auth LDAP ##########################
[auth.ldap]
;enabled = false
;config_file = /etc/grafana/ldap.toml
;allow_sign_up = true

# LDAP background sync (Enterprise only)
# At 1 am every day
;sync_cron = "0 0 1 * * *"
;active_sync_enabled = true

#################################### AWS ###########################
[aws]
# Enter a comma-separated list of allowed AWS authentication providers. 
# Options are: default (AWS SDK Default), keys (Access && secret key), credentials (Credentials field), ec2_iam_role (E>
; allowed_auth_providers = default,keys,credentials

# Allow AWS users to assume a role using temporary security credentials. 
# If true, assume role will be enabled for all AWS authentication providers that are specified in aws_auth_providers
; assume_role_enabled = true

#################################### SMTP / Emailing ##########################
[smtp]
;enabled = false
;host = localhost:25
;user =
# If the password contains # or ; you have to wrap it with triple quotes. Ex """#password;"""
;password =
;cert_file =
;key_file =
;skip_verify = false
;from_address = admin@grafana.localhost
;from_name = Grafana
# EHLO identity in SMTP dialog (defaults to instance_name)
;ehlo_identity = dashboard.example.com
# SMTP startTLS policy (defaults to 'OpportunisticStartTLS')
;startTLS_policy = NoStartTLS

[emails]
;welcome_email_on_sign_up = false
;templates_pattern = emails/*.html

#################################### Logging ##########################
[log]
# Either "console", "file", "syslog". Default is console and  file
# Use space to separate multiple modes, e.g. "console file"
;mode = console file

# Either "debug", "info", "warn", "error", "critical", default is "info"
;level = info

# optional settings to set different levels for specific loggers. Ex filters = sqlstore:debug
;filters =

# For "console" mode only
[log.console]
;level =

# log line format, valid options are text, console and json
;format = console

# For "file" mode only
[log.file]
;level =

# log line format, valid options are text, console and json
;format = text

# This enables automated log rotate(switch of following options), default is true
;log_rotate = true

# Max line number of single file, default is 1000000
;max_lines = 1000000

# Max size shift of single file, default is 28 means 1 << 28, 256MB
;max_size_shift = 28

# Segment log daily, default is true
;daily_rotate = true

# Expired days of log file(delete after max days), default is 7
;max_days = 7

[log.syslog]
;level =

# log line format, valid options are text, console and json
;format = text

# Syslog network type and address. This can be udp, tcp, or unix. If left blank, the default unix endpoints will be use>
;network =
;address =

# Syslog facility. user, daemon and local0 through local7 are valid.
;facility =

# Syslog tag. By default, the process' argv[0] is used.
;tag =

[log.frontend]
# Should Sentry javascript agent be initialized
;enabled = false

# Sentry DSN if you want to send events to Sentry.
;sentry_dsn =

# Custom HTTP endpoint to send events captured by the Sentry agent to. Default will log the events to stdout.
;custom_endpoint = /log

# Rate of events to be reported between 0 (none) and 1 (all), float
;sample_rate = 1.0

# Requests per second limit enforced an extended period, for Grafana backend log ingestion endpoint (/log).
;log_endpoint_requests_per_second_limit = 3

# Max requests accepted per short interval of time for Grafana backend log ingestion endpoint (/log).
;log_endpoint_burst_limit = 15

#################################### Usage Quotas ########################
[quota]
; enabled = false

#### set quotas to -1 to make unlimited. ####
# limit number of users per Org.
; org_user = 10

# limit number of dashboards per Org.
; org_dashboard = 100

# limit number of data_sources per Org.
; org_data_source = 10

# limit number of api_keys per Org.
; org_api_key = 10

# limit number of orgs a user can create.
; user_org = 10

# Global limit of users.
; global_user = -1

# global limit of orgs.
; global_org = -1

# global limit of dashboards
; global_dashboard = -1

# global limit of api_keys
; global_api_key = -1

# global limit on number of logged in users.
; global_session = -1

#################################### Alerting ############################
[alerting]
# Disable alerting engine & UI features
;enabled = true
# Makes it possible to turn off alert rule execution but alerting UI is visible
;execute_alerts = true

# Default setting for new alert rules. Defaults to categorize error and timeouts as alerting. (alerting, keep_state)
;error_or_timeout = alerting

# Default setting for how Grafana handles nodata or null values in alerting. (alerting, no_data, keep_state, ok)
;nodata_or_nullvalues = no_data

# Alert notifications can include images, but rendering many images at the same time can overload the server
# This limit will protect the server from render overloading and make sure notifications are sent out quickly
;concurrent_render_limit = 5


# Default setting for alert calculation timeout. Default value is 30
;evaluation_timeout_seconds = 30

# Default setting for alert notification timeout. Default value is 30
;notification_timeout_seconds = 30

# Default setting for max attempts to sending alert notifications. Default value is 3
;max_attempts = 3

# Makes it possible to enforce a minimal interval between evaluations, to reduce load on the backend
;min_interval_seconds = 1

# Configures for how long alert annotations are stored. Default is 0, which keeps them forever.
# This setting should be expressed as a duration. Examples: 6h (hours), 10d (days), 2w (weeks), 1M (month).
;max_annotation_age =

# Configures max number of alert annotations that Grafana stores. Default value is 0, which keeps all alert annotations.
;max_annotations_to_keep =

#################################### Annotations #########################
[annotations]
# Configures the batch size for the annotation clean-up job. This setting is used for dashboard, API, and alert annotat>
;cleanupjob_batchsize = 100

[annotations.dashboard]
# Dashboard annotations means that annotations are associated with the dashboard they are created on.

# Configures how long dashboard annotations are stored. Default is 0, which keeps them forever.
# This setting should be expressed as a duration. Examples: 6h (hours), 10d (days), 2w (weeks), 1M (month).
;max_age =

# Configures max number of dashboard annotations that Grafana stores. Default value is 0, which keeps all dashboard ann>
;max_annotations_to_keep =

[annotations.api]
# API annotations means that the annotations have been created using the API without any
# association with a dashboard.

# Configures how long Grafana stores API annotations. Default is 0, which keeps them forever.
# This setting should be expressed as a duration. Examples: 6h (hours), 10d (days), 2w (weeks), 1M (month).
;max_age =

# Configures max number of API annotations that Grafana keeps. Default value is 0, which keeps all API annotations.
;max_annotations_to_keep =

#################################### Explore #############################
[explore]
# Enable the Explore section
;enabled = true

#################################### Internal Grafana Metrics ##########################
# Metrics available at HTTP API Url /metrics
[metrics]
# Disable / Enable internal metrics
;enabled           = true
# Graphite Publish interval
;interval_seconds  = 10
# Disable total stats (stat_totals_*) metrics to be generated
;disable_total_stats = false

#If both are set, basic auth will be required for the metrics endpoint.
; basic_auth_username =
; basic_auth_password =

# Metrics environment info adds dimensions to the `grafana_environment_info` metric, which
# can expose more information about the Grafana instance.
[metrics.environment_info]
#exampleLabel1 = exampleValue1
#exampleLabel2 = exampleValue2

# Send internal metrics to Graphite
[metrics.graphite]
# Enable by setting the address setting (ex localhost:2003)
;address =
;prefix = prod.grafana.%(instance_name)s.

#################################### Grafana.com integration  ##########################
# Url used to import dashboards directly from Grafana.com
[grafana_com]
;url = https://grafana.com

#################################### Distributed tracing ############
[tracing.jaeger]
# Enable by setting the address sending traces to jaeger (ex localhost:6831)
;address = localhost:6831
# Tag that will always be included in when creating new spans. ex (tag1:value1,tag2:value2)
;always_included_tag = tag1:value1
# Type specifies the type of the sampler: const, probabilistic, rateLimiting, or remote
;sampler_type = const
# jaeger samplerconfig param
# for "const" sampler, 0 or 1 for always false/true respectively
# for "probabilistic" sampler, a probability between 0 and 1
# for "rateLimiting" sampler, the number of spans per second
# for "remote" sampler, param is the same as for "probabilistic"
# and indicates the initial sampling rate before the actual one
# is received from the mothership
;sampler_param = 1
# sampling_server_url is the URL of a sampling manager providing a sampling strategy.
;sampling_server_url =
# Whether or not to use Zipkin propagation (x-b3- HTTP headers).
;zipkin_propagation = false
# Setting this to true disables shared RPC spans.
# Not disabling is the most common setting when using Zipkin elsewhere in your infrastructure.
;disable_shared_zipkin_spans = false

#################################### External image storage ##########################
[external_image_storage]
# Used for uploading images to public servers so they can be included in slack/email messages.
# you can choose between (s3, webdav, gcs, azure_blob, local)
;provider =

[external_image_storage.s3]
;endpoint =
;path_style_access =
;bucket =
;region =
;path =
;access_key =
;secret_key =

[external_image_storage.webdav]
;url =
;public_url =
;username =
;password =

[external_image_storage.gcs]
;key_file =
;bucket =
;path =

[external_image_storage.azure_blob]
;account_name =
;account_key =
;container_name =

[external_image_storage.local]
# does not require any configuration

[rendering]
# Options to configure a remote HTTP image rendering service, e.g. using https://github.com/grafana/grafana-image-renderer.
# URL to a remote HTTP image renderer service, e.g. http://localhost:8081/render, will enable Grafana to render panels and dashboards to PNG-images using HTTP requests to an external service.
;server_url =
# If the remote HTTP image renderer service runs on a different server than the Grafana server you may have to configure this to a URL where Grafana is reachable, e.g. http://grafana.domain/.
;callback_url =
# Concurrent render request limit affects when the /render HTTP endpoint is used. Rendering many images at the same time can overload the server,
# which this setting can help protect against by only allowing a certain amount of concurrent requests.
;concurrent_render_request_limit = 30

[panels]
# If set to true Grafana will allow script tags in text panels. Not recommended as it enable XSS vulnerabilities.
;disable_sanitize_html = false

[plugins]
;enable_alpha = false
;app_tls_skip_verify_insecure = false
# Enter a comma-separated list of plugin identifiers to identify plugins that are allowed to be loaded even if they lack a valid signature.
;allow_loading_unsigned_plugins =
;marketplace_url = https://grafana.com/grafana/plugins/

#################################### Grafana Image Renderer Plugin ##########################
[plugin.grafana-image-renderer]
# Instruct headless browser instance to use a default timezone when not provided by Grafana, e.g. when rendering panel image of alert.
# See ICU’s metaZones.txt (https://cs.chromium.org/chromium/src/third_party/icu/source/data/misc/metaZones.txt) for a list of supported
# timezone IDs. Fallbacks to TZ environment variable if not set.
;rendering_timezone =

# Instruct headless browser instance to use a default language when not provided by Grafana, e.g. when rendering panel image of alert.
# Please refer to the HTTP header Accept-Language to understand how to format this value, e.g. 'fr-CH, fr;q=0.9, en;q=0.8, de;q=0.7, *;q=0.5'.
;rendering_language =

# Instruct headless browser instance to use a default device scale factor when not provided by Grafana, e.g. when rendering panel image of alert.
# Default is 1. Using a higher value will produce more detailed images (higher DPI), but will require more disk space to store an image.
;rendering_viewport_device_scale_factor =

# Instruct headless browser instance whether to ignore HTTPS errors during navigation. Per default HTTPS errors are not ignored. Due to
# the security risk it's not recommended to ignore HTTPS errors.
;rendering_ignore_https_errors =

# Instruct headless browser instance whether to capture and log verbose information when rendering an image. Default is false and will
# only capture and log error messages. When enabled, debug messages are captured and logged as well.
# For the verbose information to be included in the Grafana server log you have to adjust the rendering log level to debug, configure
# [log].filter = rendering:debug.
;rendering_verbose_logging =

# Instruct headless browser instance whether to output its debug and error messages into running process of remote rendering service.
# Default is false. This can be useful to enable (true) when troubleshooting.
;rendering_dumpio =

# Additional arguments to pass to the headless browser instance. Default is --no-sandbox. The list of Chromium flags can be found
# here (https://peter.sh/experiments/chromium-command-line-switches/). Multiple arguments is separated with comma-character.
;rendering_args =

# You can configure the plugin to use a different browser binary instead of the pre-packaged version of Chromium.
# Please note that this is not recommended, since you may encounter problems if the installed version of Chrome/Chromium is not
# compatible with the plugin.
;rendering_chrome_bin =

# Instruct how headless browser instances are created. Default is 'default' and will create a new browser instance on each request.
# Mode 'clustered' will make sure that only a maximum of browsers/incognito pages can execute concurrently.
# Mode 'reusable' will have one browser instance and will create a new incognito page on each request.
;rendering_mode =

# When rendering_mode = clustered you can instruct how many browsers or incognito pages can execute concurrently. Default is 'browser'
# and will cluster using browser instances.
# Mode 'context' will cluster using incognito pages.
;rendering_clustering_mode =
# When rendering_mode = clustered you can define maximum number of browser instances/incognito pages that can execute concurrently..
;rendering_clustering_max_concurrency =

# Limit the maximum viewport width, height and device scale factor that can be requested.
;rendering_viewport_max_width =
;rendering_viewport_max_height =
;rendering_viewport_max_device_scale_factor =

# Change the listening host and port of the gRPC server. Default host is 127.0.0.1 and default port is 0 and will automatically assign
# a port not in use.
;grpc_host =
;grpc_port =

[enterprise]
# Path to a valid Grafana Enterprise license.jwt file
;license_path =

[feature_toggles]
# enable features, separated by spaces
;enable =

[date_formats]
# For information on what formatting patterns that are supported https://momentjs.com/docs/#/displaying/

# Default system date format used in time range picker and other places where full time is displayed
;full_date = YYYY-MM-DD HH:mm:ss

# Used by graph and other places where we only show small intervals
;interval_second = HH:mm:ss
;interval_minute = HH:mm
;interval_hour = MM/DD HH:mm
;interval_day = MM/DD
;interval_month = YYYY-MM
;interval_year = YYYY

# Experimental feature
;use_browser_locale = false

# Default timezone for user preferences. Options are 'browser' for the browser local timezone or a timezone name from IANA Time Zone database, e.g. 'UTC' or 'Europe/Amsterdam' etc.
;default_timezone = browser

[expressions]
# Enable or disable the expressions functionality.
;enabled = true

EOF
)"
echo "${grafanaini}" > /etc/grafana/grafana.ini

sudo systemctl daemon-reload
sudo systemctl stop grafana-server
sudo systemctl start grafana-server

# start service on system boot
sudo systemctl enable grafana-server.service

printf >&2 "Please go to admin url: Now you should be able to browse to the Grafana interface at https://${domain}:3000\n\n"
printf >&2 "1. Sign into Grafana (admin / admin) and change the admin password.\n\n"
printf >&2 "2. You can customise the default dashboard by saving a copy.\n\n"
printf >&2 "\n\n"
printf >&2 "URL Action Address is:\n\n"
printf >&2 "https://${domain}:3000/d/pLkA1-inz/tacticalrmm-dashboard-trmm?orgId=1&var-Client={{client.name}}&var-Sites={{site.name}}&var-Agents_HostName={{agent.hostname}}\n\n"



echo "Press any key to finish install"
while [ true ] ; do
read -t 3 -n 1
if [ $? = 0 ] ; then
exit ;
else
echo "waiting for the keypress"
fi
done
