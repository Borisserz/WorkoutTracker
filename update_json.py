import json

with open('remote_config.json', 'r') as f:
    data = json.load(f)

data['parameters']['show_foodtracker_promo'] = {
    'defaultValue': {
        'value': '1'
    },
    'valueType': 'STRING'
}

with open('remote_config.json', 'w') as f:
    json.dump(data, f, indent=2)
