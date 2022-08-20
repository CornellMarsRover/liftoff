import time
import requests
import sys

# Script to automatically add the SSH keys to the device

if len(sys.argv) != 2:
    print("Missing public key argument/invalid arguments")
    sys.exit(1)


public_key = sys.argv[1]

# Get device code and verification url
headers = {"Accept": "application/json"}
response = requests.post("https://github.com/login/device/code",\
    data = {"client_id": "ff34863a13a9aa66ae1e", "scope": "user, admin:public_key"},\
        headers = headers)
if response.status_code != 200:
    print("Unable to make authentication request, stopping")
    print(f"{response}")
    sys.exit(2)


resp_json = response.json()
user_code = resp_json["user_code"]
user_url = resp_json["verification_uri"]
device_code = resp_json["device_code"]
waiting_interval = resp_json["interval"]

# Prompt user to authenticate
print(f"Please go to {user_url} and enter the following code: {user_code}")
print("This script will continue once you have authenticated in your browser")

data = {"device_code": device_code, "client_id": "ff34863a13a9aa66ae1e",\
    "grant_type": "urn:ietf:params:oauth:grant-type:device_code"}

# Poll and wait until user authenticates
access_token = ""
while True:
    
    time.sleep(waiting_interval + 0.2)
    response = requests.post("https://github.com/login/oauth/access_token",\
        data, headers = headers)

    if response.status_code != 200:
        print("Unable to get device code")
        print(f"{response.json()}")
        sys.exit(3)

    resp = dict(response.json())

    if "access_token" in resp.keys():
        access_token = response.json()["access_token"]
        break

# Create SSH Key
headers = {"Authorization": f"token {access_token}",\
    "Accept": "application/json"}
data = {"title": "CMR Git CLI", "key": f"{public_key}\n"}
response = requests.post("https://api.github.com/user/keys", json = data,\
    headers = headers)

if response.status_code == 201:
    print("SSH key successfully added to github")
elif response.status_code == 304:
    print("SSH key already exists on user account")
else:
    print("SSH key could not be added")
    print(response.request.body)
    sys.exit(4)
