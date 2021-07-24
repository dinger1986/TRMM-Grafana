import http.client, urllib.parse, json, sys
from urllib.request import urlopen
 
#customField geohas is empty
if len(str(sys.argv[2])) == 2:    
    #customField adressePostal is not empty
  if len(str(sys.argv[1])) > 2:  
  
    #recovery of contact details with the site https://positionstack.com/ for more information look documentation https://positionstack.com/documentation
    conn = http.client.HTTPConnection('api.positionstack.com')  
    params = urllib.parse.urlencode({
        #[Required] Your API access key, which can be found in your acccount dashboard.
        'access_key': 'youKeyAPI',
        #[Required] Specify your query as a free-text address, 
        #place name or using any other common text-based location identifier 
        #(e.g. postal code, city name, region name).
        'query': str(sys.argv[1]),
        #return the best result
        'limit': 1,
        })
    
    conn.request('GET', '/v1/forward?{}'.format(params))
    
    res = conn.getresponse()
    data = res.read()
    
    #Debug show Json
    #print(data.decode('utf-8'))
    
    y = json.loads(data.decode('utf-8'))
    
    # the result is a Python dictionary:
    #Debug show latitude and longitude in output
      #print(y["data"][0]["latitude"])
      #print(y["data"][0]["longitude"])
    
    #Recuperation du geohash depuis le site http://geohash.world en lui passant la latitude et la longitude
    url = "http://geohash.world/v1/encode/" + str(y["data"][0]["latitude"]) + "," + str(y["data"][0]["longitude"]) + "?pre=10"
      
    #store the response of URL
    response = urlopen(url)
      
    # storing the JSON response 
    # from url in data
    data_json = json.loads(response.read())
      
    # print the json response
    print(data_json["geohash"])
  
  #customField adressePostal is empty
  else:  
  
    with urllib.request.urlopen("http://ip-api.com/json/") as url:
      data = json.loads(url.read().decode())
  
      #Debug show latitude and longitude in output
        #print(data)
        #print(data["lat"])
        #print(data["lon"])
      
    #Recuperation du geohash depuis le site http://geohash.world en lui passant la latitude et la longitude
    url = "http://geohash.world/v1/encode/" + str(data["lat"]) + "," + str(data["lon"]) + "?pre=10"
      
    # store the response of URL
    response = urlopen(url)
      
    # storing the JSON response 
    # from url in data
    data_json = json.loads(response.read())
      
    # print the json response
    print(data_json["geohash"])

#customField geohash is not empty
else:  
  print(str(sys.argv[2]))
