# emergency update abi for gnosis wallet
# target contract: GovHub address
# [{"inputs": [{"internalType": "string","name": "key","type": "string"},{"internalType": "bytes","name": "values","type": "bytes"},{"internalType": "bytes","name": "targets","type": "bytes"}],"name": "emergencyUpdate","outputs": [],"stateMutability": "nonpayable","type": "function"}]

# 1. generate EmergencyUpgrade params
# set target contract and new implement contract
forge script foundry-scripts/EmergencyOperator.s.sol:EmergencyOperatorScript \
--sig "generateEmergencyUpgrade(address target, address newImpl)" \
${the target contract} ${new implement for the target} \
-f https://data-seed-prebsc-1-s1.binance.org:8545/ \
--legacy --ffi

# 2. generate EmergencyUpgrade contracts params
# set target contracts and new implement contracts
# params example: "[0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266]" "[0x70997970C51812dc3A010C7d01b50e0d17dc79C8,0x70997970C51812dc3A010C7d01b50e0d17dc79C8]"
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

# 4. send emergencySuspend tx on testnet
forge script foundry-scripts/EmergencyOperator.s.sol:EmergencyOperatorScript \
--private-key ${your private key} \
--sig "emergencySuspend()" \
-f https://data-seed-prebsc-1-s1.binance.org:8545/ \
--legacy --ffi --broadcast

# 5. send emergencyReopen tx
forge script foundry-scripts/EmergencyOperator.s.sol:EmergencyOperatorScript \
--private-key ${your private key} \
--sig "emergencyReopen()" \
-f https://data-seed-prebsc-1-s1.binance.org:8545/ \
--legacy --ffi --broadcast

# 6. send emergencyCancelTransfer tx
forge script foundry-scripts/EmergencyOperator.s.sol:EmergencyOperatorScript \
--private-key ${your private key} \
--sig "emergencyCancelTransfer(address attacker)" \
${attacker address} \
-f https://data-seed-prebsc-1-s1.binance.org:8545/ \
--legacy --ffi --broadcast
