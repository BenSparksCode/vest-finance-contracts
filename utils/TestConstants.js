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
    DAI_WHALE: "0xB78e90E2eC737a2C0A24d68a0e54B410FFF3bD6B",
  },
  TEST: {
    oneDai: ethers.utils.parseEther("1"),
    oneDay: 86400,
    oneMonth: 2629800,
  },
  DEPLOY: {
    ERR_TOL_DIV: 10000, // error tolerance divisor
    SCALE: ethers.utils.parseEther("1"),
    fee: ethers.utils.parseEther("0.001"),
  },
};

module.exports = {
  constants: CONSTANTS,
};
