#!/usr/bin/env bash
contract=$1
cat ${contract} | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['Deployer'])"
