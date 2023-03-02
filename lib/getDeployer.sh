#!/usr/bin/env bash
contract=$1
number=$2
cat ${contract} | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['Deployer${number}'])"
