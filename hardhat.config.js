require("dotenv").config();

require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-etherscan");
require("solidity-coverage");

module.exports = {
  solidity: {
    version: "0.8.11",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {
      blockGasLimit: 12500000,
      gasPrice: 8000000000
    },
    mumbai: {
      url: process.env.MUMBAI_URL,
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    polygon: {
      url: process.env.POLYGON_URL,
      accounts:
      process.env.POLYGON_PRIVATE_KEY !== undefined ? [process.env.POLYGON_PRIVATE_KEY] : [],
    },
    vivid: {
      url: process.env.VIVID_URL,
      accounts:
      process.env.VIVID_PRIVATE_KEY !== undefined ? [process.env.VIVID_PRIVATE_KEY] : [],
    }
  },
  etherscan: {
    apiKey: {
      polygon: process.env.MUMBAI_API_KEY,
      vivid: process.env.SCOUT_API_KEY,
    },
    customChains: [
      {
        network: "vivid",
        chainId: 1,
        urls: {
          apiURL: "https://explorer.dev.videocoin.network/api",
          browserURL: "https://explorer.dev.videocoin.network"
        }
      }
    ]
  }
};
