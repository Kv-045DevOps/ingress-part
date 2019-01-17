#!/usr/bin/python3
import requests
import json

with open('zone-ns.json') as f:
    route53_nameservers = json.load(f)

payload = list()

for ns in route53_nameservers:
	record = {
    "type": "NS",
    "name": "@",
    "data": ns,
    "ttl": 3600
	}
	payload.append(record)

with open('domain-update.json', 'w') as f:
	f.write(json.dumps(payload, indent=4) + "\n")