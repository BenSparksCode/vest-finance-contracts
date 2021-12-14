const { expect } = require("chai");
const { ethers } = require("hardhat");
const hre = require("hardhat");
const { constants } = require("../utils/TestConstants");
const {
  currentTime,
  fastForward,
  sendDaiFromWhale,
} = require("../utils/TestUtils");
const { BigNumber } = require("ethers");

let owner, ownerAddress;
let alice, bob, chad;
let aliceAddress, bobAddress, chadAddress;
let whale, whaleAddress;

let CoreContract, CoreInstance;

let startTime, endTime;

const ERC20_ABI = require("../artifacts/contracts/BaseERC20.sol/BaseERC20.json");
const DAI = new ethers.Contract(
  constants.POLYGON.DAI,
  ERC20_ABI.abi,
  ethers.provider
);

describe("VestCore Unit Tests", function () {
  beforeEach(async () => {
    [owner, alice, bob, chad] = await ethers.getSigners();

    console.log(1);

    ownerAddress = await owner.getAddress();
    aliceAddress = await alice.getAddress();
    bobAddress = await bob.getAddress();
    chadAddress = await chad.getAddress();

    console.log(2);

    // Deploy core
    CoreContract = await ethers.getContractFactory("VestCore");
    CoreInstance = await CoreContract.connect(owner).deploy();

    console.log(3);

    // Creating DAI token instance
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [constants.POLYGON.DAI_WHALE],
    });

    console.log(4);

    whale = await ethers.getSigner(constants.POLYGON.DAI_WHALE);
    whaleAddress = await whale.getAddress();

    console.log(5);

    // Give whale some ETH
    await alice.sendTransaction({
      to: whaleAddress,
      value: ethers.utils.parseEther("1"),
    });

    await sendDaiFromWhale(
      ethers.utils.parseEther("100"),
      whale,
      alice,
      CoreInstance.address
    );

    startTime = await currentTime();
    endTime = startTime + constants.TEST.oneMonth;
  });

  // -----------------
  // createVestingBox
  // -----------------

  describe("createVestingBox", function () {
    it("createVestingBoxWithExistingToken - normal args", async () => {
      const vBox = {};
      const vBoxAccounts = [];

      //   await CoreInstance.connect(alice).createVestingBox(

      //   );
    });
  });
});
