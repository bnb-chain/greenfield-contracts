import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.17",


    networks: {
        'local': {
            url: "http://127.0.0.1:8545",
            accounts: [
                '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',  // developer
                '0x242fcddc7fb52093a183b11f8081dea3c7618da7158ac940c069ff7819cf58e8',  // relayer
            ]
        }
  }
};

export default config;
