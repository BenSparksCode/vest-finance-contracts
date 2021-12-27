const { expect } = require("chai");
const { ethers } = require("hardhat");
const hre = require("hardhat");
const { constants } = require("../utils/TestConstants");
const {
  currentTime,
  fastForward,
  sendDaiFromWhale,
  createBasicVestingBox,
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

describe("VestCore Scenario Tests", function () {
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

  describe("Scenarios", function () {
    it("DAI, 1 recipient, 100 day vest, 2 claims", async () => {
      // Creator: Alice
      // Recipients: Bob
      startTime = await currentTime();
      endTime = startTime + 100 * constants.TEST.oneDay;
      const totalAmount = ethers.utils.parseEther("10");
      const vBox = {
        token: constants.POLYGON.DAI,
        creator: aliceAddress,
      };
      const vBoxAccounts = [
        {
          amount: ethers.utils.parseEther("10"),
          withdrawn: 0,
          startTime: startTime,
          endTime: endTime,
        },
      ];
      const vBoxAddresses = {
        admins: [aliceAddress],
        recipients: [bobAddress],
      };

      await CoreInstance.connect(alice).createVestingBoxWithExistingToken(
        totalAmount,
        vBox,
        vBoxAccounts,
        vBoxAddresses
      );

      // Fast forward 50 days
      await fastForward(50 * constants.TEST.oneDay);

      //   TODO check data

      withdrawableAmount = await getWithdrawableAmount(1, bobAddress);
      vestedAmount = await getVestedAmount(1, bobAddress);

      expect(withdrawableAmount).to.equal(afterFee());

      // Bob withdraws half
      await CoreInstance.connect(bob).claimVestedTokens(1);
    });

    it("new token", async () => {
      const totalAmount = ethers.utils.parseEther("10");
      const vBox = {
        token: constants.POLYGON.DAI,
        creator: ownerAddress,
      };
      const vBoxAccounts = [
        {
          amount: ethers.utils.parseEther("10"),
          withdrawn: 0,
          startTime: startTime,
          endTime: endTime,
        },
      ];
      const vBoxAddresses = {
        admins: [aliceAddress],
        recipients: [bobAddress],
      };

      await CoreInstance.connect(alice).createVestingBoxWithNewToken(
        totalAmount,
        vBox,
        vBoxAccounts,
        vBoxAddresses,
        "Test coin",
        "TEST",
        ethers.utils.parseEther("50")
      );
    });

    it("with ETH", async () => {
      const totalAmount = ethers.utils.parseEther("10");
      const vBox = {
        token: constants.POLYGON.DAI,
        creator: ownerAddress,
      };
      const vBoxAccounts = [
        {
          amount: ethers.utils.parseEther("10"),
          withdrawn: 0,
          startTime: startTime,
          endTime: endTime,
        },
      ];
      const vBoxAddresses = {
        admins: [aliceAddress],
        recipients: [bobAddress],
      };

      await CoreInstance.connect(alice).createVestingBoxWithETH(
        totalAmount,
        vBox,
        vBoxAccounts,
        vBoxAddresses,
        {
          value: totalAmount,
        }
      );
    });
  });

  describe("View Functions", function () {
    it("Public vBoxes mapping returns VestingBox object", async () => {
      await createBasicVestingBox(CoreInstance, alice, bobAddress, chadAddress);

      const vBox = await CoreInstance.vBoxes(1);

      expect(vBox.token).to.equal(constants.POLYGON.DAI);
      expect(vBox.creator).to.equal(aliceAddress);
    });
    it("Public vBoxAccounts mapping returns VestingBoxAccount object", async () => {
      startTime = await currentTime();
      endTime = startTime + 100 * constants.TEST.oneDay;
      await createBasicVestingBox(CoreInstance, alice, bobAddress, chadAddress);

      const vBoxAccount = await CoreInstance.vBoxAccounts(1, bobAddress);

      expect(vBoxAccount.amount).to.equal(ethers.utils.parseEther("50"));
      expect(vBoxAccount.withdrawn).to.equal(0);
      expect(vBoxAccount.startTime).to.equal(startTime);
      expect(vBoxAccount.endTime).to.equal(endTime);
    });
  });
});
