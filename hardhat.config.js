require("dotenv").config();

require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-etherscan");
require("solidity-coverage");

module.exports = {
  solidity: {
    version: "0.8.7",
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
  },
  etherscan: {
    apiKey: {
      polygonMumbai: process.env.MUMBAI_API_KEY,
    },
    customChains: [  // <========================= custom chains config here
      {
        network: 'polygonMumbai',
        chainId: 80001,
        urls: {
          apiURL: 'http://api-testnet.polygonscan.com/api',  // https => http
          browserURL: 'https://mumbai.polygonscan.com',
        },
      },
    ],
  },
};
