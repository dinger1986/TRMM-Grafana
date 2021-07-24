# Get City for Collectors
Invoke-RestMethod -Uri 'http://ipinfo.io/' | select geohas
