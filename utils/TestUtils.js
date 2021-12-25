const { ethers } = require("hardhat");
const { BigNumber } = require("@ethersproject/bignumber");
const { constants } = require("./TestConstants");

const ERC20_ABI = require("../artifacts/contracts/BaseERC20.sol/BaseERC20.json");
const DAI = new ethers.Contract(
  constants.POLYGON.DAI,
  ERC20_ABI.abi,
  ethers.provider
);

// Gets the time of the last block.
const currentTime = async () => {
  const { timestamp } = await ethers.provider.getBlock("latest");
  return timestamp;
};

// Increases the time in the EVM.
// seconds = number of seconds to increase the time by
const fastForward = async (seconds) => {
  await ethers.provider.send("evm_increaseTime", [seconds]);
  await ethers.provider.send("evm_mine", []);
};

const toJSNum = (bigNum) => {
  return parseInt(bigNum.toString());
};

const burnTokenBalance = async (signer, tokenContract) => {
  const addr = await signer.getAddress();
  const bal = await tokenContract.balanceOf(addr);
  tokenContract
    .connect(signer)
    .transfer("0x000000000000000000000000000000000000dEaD", bal);
};

const sendDaiFromWhale = async (amount, whaleSigner, toSigner, coreAddress) => {
  await DAI.connect(whaleSigner).transfer(toSigner.address, amount);
  await DAI.connect(toSigner).approve(coreAddress, amount);
};

// NOTE: creator needs to have 50 DAI
const createBasicVestingBox = async (
  coreContract,
  creatorSigner,
  recipientAddress,
  adminAddress
) => {
  // vesting starts now, ends in 100 days
  const startTime = await currentTime();
  const endTime = startTime + 100 * constants.TEST.oneDay;
  const totalAmount = ethers.utils.parseEther("50");

  const vBox = {
    token: constants.POLYGON.DAI,
    creator: creatorSigner.address,
  };
  const vBoxAccounts = [
    {
      amount: totalAmount,
      withdrawn: 0,
      startTime: startTime,
      endTime: endTime,
    },
  ];
  const vBoxAddresses = {
    admins: [adminAddress],
    recipients: [recipientAddress],
  };

  await DAI.connect(creatorSigner).approve(coreContract.address, totalAmount);
  await coreContract
    .connect(creatorSigner)
    .createVestingBoxWithExistingToken(
      totalAmount,
      vBox,
      vBoxAccounts,
      vBoxAddresses
    );
};

module.exports = {
  currentTime: currentTime,
  fastForward: fastForward,
  burnTokenBalance: burnTokenBalance,
  sendDaiFromWhale: sendDaiFromWhale,
  createBasicVestingBox: createBasicVestingBox,
};
