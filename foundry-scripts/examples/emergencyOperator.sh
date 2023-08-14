# 1. generate EmergencyUpgrade params
# set target contract and new implement contract
forge script foundry-scripts/EmergencyOperator.s.sol:EmergencyOperatorScript \
--sig "generateEmergencyUpgrade(address target, address newImpl)" \
${the target contract} ${new implement for the target} \
-f https://data-seed-prebsc-1-s1.binance.org:8545/ \
--legacy --ffi

# 2. generate EmergencyUpgrade contracts params
# set target contracts and new implement contracts
forge script foundry-scripts/EmergencyOperator.s.sol:EmergencyOperatorScript \
--sig "generateEmergencyUpgrades(address[] memory _targets, address[] memory _newImpls)" \
${the target contracts separated by commas} ${new implements separated by commas} \
-f https://data-seed-prebsc-1-s1.binance.org:8545/ \
--legacy --ffi

# 3. generate Emergency UpdateParam
# set key, target contract and new value
forge script foundry-scripts/EmergencyOperator.s.sol:EmergencyOperatorScript \
--sig "generateEmergencyUpdateParam(string memory key, address target, uint256 newValue)" \
${the param key} ${the target contract} ${new value for param} \
-f https://data-seed-prebsc-1-s1.binance.org:8545/ \
--legacy --ffi

