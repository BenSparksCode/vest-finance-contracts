const { BigNumber } = require("@ethersproject/bignumber");
const { ethers } = require("hardhat");

const CONSTANTS = {
  MUMBAI: {
    DAI: "0x001B3B4d0F3714Ca98ba10F6042DaEbF0B1B7b6F",
    aDAI: "0x639cB7b21ee2161DF9c882483C9D55c90c20Ca3e",
  },
  POLYGON: {
    DAI: "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063",
    aDAI: "0x27F8D03b3a2196956ED754baDc28D73be8830A6e",
  },
  SHIP: {
    decimals: 18,
    total: 100000000, //  100 million
    hackathonAirdrop: 2000000, //  2 million
    mainnetAirdrop: 8000000, //  8 million
    strategicPartners: 16000000, //  16 million
    stakingRewards: 20000000, //  20 million
    teamVesting: 24000000, //  24 million
    daoTreasury: 30000000, //  30 million
  },
  DEPLOY: {
    SHIP: {
      name: "SHIP",
      symbol: "SHIP",
      totalSupply: ethers.utils.parseUnits("100000000", "ether"), //100 million with 18 decimals
    },
    FERRY: {
      annualFee: ethers.utils.parseUnits("24", "ether"), //$24 per year to start
      maxMintedNFTs: 50000,
      maxMembershipPeriod: 2 * 365 * 86400, // 2 years = 2 * 365 days * 86400 seconds per day
      nftThreshold: ethers.utils.parseUnits("1", "ether"), //$1 Will cost less than $0.01 in LINK for random num
    },
    NFT_MINTER: {
      vrfFee: 100000000000000,
    },
    TOKENS: {
      daiApproveAmount: ethers.utils.parseUnits("30", "ether"),
      linkToMinterAmount: 1000000000000000, // 10 * 0.0001 VRF fee
    },
  },
};

module.exports = {
  constants: CONSTANTS,
};
