require("@nomiclabs/hardhat-waffle");
require("hardhat-contract-sizer");
require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-etherscan");

require("dotenv").config();

task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

module.exports = {
  solidity: "0.8.10",
  loggingEnabled: true,
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  },
  gasReporter: {
    endabled: true,
  },
  defaultNetwork: "localhost",
  networks: {
    localhost: {
      url: "http://localhost:8545",
    },
    hardhat: {
      forking: {
        url:
          "https://polygon-mainnet.g.alchemy.com/v2/" + process.env.ALCHEMY_API,
        blockNumber: 19872200,
      },
      accounts: {
        accountsBalance: "1000000000000000000000000", //1 million ETH to signers
      },
      gasPrice: 0,
    },
    mumbai: {
      url: "https://polygon-mumbai.g.alchemy.com/v2/" + process.env.ALCHEMY_API,
      accounts: [`${process.env.MUMBAI_DEPLOYER_PRIV_KEY}`],
      chainId: 80001,
      gas: 5000000, // 5 million
      gasLimit: 5000000, // 5 million
      gasPrice: 5000000000, // 5 gwei
    },
    polygon: {
      url: "https://matic-mainnet.chainstacklabs.com",
      accounts: [`${process.env.POLYGON_DEPLOYER_PRIV_KEY}`],
      chainId: 137,
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};
