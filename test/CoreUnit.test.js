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
let FactoryContract, FactoryInstance;

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

    ownerAddress = await owner.getAddress();
    aliceAddress = await alice.getAddress();
    bobAddress = await bob.getAddress();
    chadAddress = await chad.getAddress();

    // Deploy core
    CoreContract = await ethers.getContractFactory("VestCore");
    CoreInstance = await CoreContract.connect(owner).deploy();

    FactoryContract = await ethers.getContractFactory("VestERC20Factory");
    FactoryInstance = await FactoryContract.connect(owner).deploy();

    // Connect Core and Factory
    await CoreInstance.connect(owner).setTokenFactory(FactoryInstance.address);
    await FactoryInstance.connect(owner).setCoreAddress(CoreInstance.address);

    // Creating DAI token instance
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [constants.POLYGON.DAI_WHALE],
    });

    whale = await ethers.getSigner(constants.POLYGON.DAI_WHALE);
    whaleAddress = await whale.getAddress();

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
    it("existing token", async () => {
      const totalAmount = ethers.utils.parseEther("50");
      const vBox = {
        token: constants.POLYGON.DAI,
        admins: [aliceAddress],
        recipients: [bobAddress],
      };
      const vBoxAccounts = [
        {
          amount: ethers.utils.parseEther("50"),
          withdrawn: 0,
          startTime: startTime,
          endTime: endTime,
        },
      ];

      await CoreInstance.connect(alice).createVestingBoxWithExistingToken(
        totalAmount,
        vBox,
        vBoxAccounts
      );
    });

    it("new token", async () => {
      const totalAmount = ethers.utils.parseEther("50");
      const vBox = {
        token: constants.POLYGON.DAI,
        admins: [aliceAddress],
        recipients: [bobAddress],
      };
      const vBoxAccounts = [
        {
          amount: ethers.utils.parseEther("50"),
          withdrawn: 0,
          startTime: startTime,
          endTime: endTime,
        },
      ];

      await CoreInstance.connect(alice).createVestingBoxWithNewToken(
        totalAmount,
        vBox,
        vBoxAccounts,
        "Test coin",
        "TEST",
        ethers.utils.parseEther("50")
      );
    });

    it("with ETH", async () => {
      const totalAmount = ethers.utils.parseEther("50");
      const vBox = {
        token: ethers.constants.AddressZero,
        admins: [aliceAddress],
        recipients: [bobAddress],
      };
      const vBoxAccounts = [
        {
          amount: ethers.utils.parseEther("50"),
          withdrawn: 0,
          startTime: startTime,
          endTime: endTime,
        },
      ];

      await CoreInstance.connect(alice).createVestingBoxWithETH(
        totalAmount,
        vBox,
        vBoxAccounts,
        {
          value: totalAmount,
        }
      );
    });
  });
});
