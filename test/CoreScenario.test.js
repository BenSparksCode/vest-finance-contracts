const { expect } = require("chai");
const { ethers } = require("hardhat");
const hre = require("hardhat");
const { constants } = require("../utils/TestConstants");
const {
  currentTime,
  fastForward,
  sendDaiFromWhale,
  createBasicVestingBox,
  afterFee,
  totalFeeOnAmount,
} = require("../utils/TestUtils");
const { BigNumber } = require("ethers");

let owner, ownerAddress;
let alice, bob, chad;
let aliceAddress, bobAddress, chadAddress;
let whale, whaleAddress;

let CoreContract, CoreInstance;
let FactoryContract, FactoryInstance;
let TokenContract, TokenInstance;

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

    // Deploying test ERC20 token - mint 1 mil to owner
    TokenContract = await ethers.getContractFactory("VestERC20");
    TokenInstance = await TokenContract.connect(owner).deploy(
      "Test Token",
      "TEST",
      ethers.utils.parseEther("1000000"), // 1 mil x 10^18
      ownerAddress
    );

    // Connect Core and Factory
    await CoreInstance.connect(owner).setTokenFactory(FactoryInstance.address);
    await FactoryInstance.connect(owner).setCoreAddress(CoreInstance.address);

    startTime = await currentTime();
    endTime = startTime + constants.TEST.oneMonth;
  });

  // -----------------
  // createVestingBox
  // -----------------

  // SCENARIO TEST 1
  // - Existing token (TEST)
  // - 1 recipient (10 TEST)
  // - 100 day vesting period
  // - claim half way and at end

  describe("Scenarios", function () {
    it("SCEN 1 - Existing token, 1 recipient, 100 day vest, 2 claims", async () => {
      // Creator: Alice
      // Recipients: Bob
      // Check balances halfway (50 days) and at end (100 days)
      let expectedWithdrawable,
        expectedVested,
        vestedAmount,
        withdrawableAmount;
      let expectedBalance, bobBalance, aliceBalance;
      const totalAmount = ethers.utils.parseEther("10");
      await TokenInstance.connect(owner).transfer(aliceAddress, totalAmount);
      await TokenInstance.connect(alice).approve(
        CoreInstance.address,
        totalAmount
      );

      startTime = await currentTime();
      endTime = startTime + 100 * constants.TEST.oneDay;

      const vBox = {
        token: TokenInstance.address,
        creator: aliceAddress,
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
        admins: [aliceAddress],
        recipients: [bobAddress],
      };

      await CoreInstance.connect(alice).createVestingBoxWithExistingToken(
        totalAmount,
        vBox,
        vBoxAccounts,
        vBoxAddresses
      );

      // Fast forward 50 days - halfway through vesting
      await fastForward(50 * constants.TEST.oneDay);

      // Check withdrawable and vested amounts are as expected
      bobBalance = await TokenInstance.balanceOf(bobAddress);
      vestedAmount = await CoreInstance.getVestedAmount(1, bobAddress);
      withdrawableAmount = await CoreInstance.getWithdrawableAmount(
        1,
        bobAddress
      );

      expectedWithdrawable = afterFee(totalAmount.div(2));
      expectedVested = totalAmount.div(2);
      expect(bobBalance).to.equal(0);
      expect(withdrawableAmount).to.be.closeTo(
        expectedWithdrawable,
        expectedWithdrawable.div(constants.DEPLOY.ERR_TOL_DIV)
      );
      expect(vestedAmount).to.be.closeTo(
        expectedVested,
        expectedVested.div(constants.DEPLOY.ERR_TOL_DIV)
      );

      expectedBalance = withdrawableAmount;

      // Bob withdraws max withdrawable (half of total)
      await CoreInstance.connect(bob).claimVestedTokens(1, withdrawableAmount);

      // Check amounts again, withdrawable should be close to 0
      bobBalance = await TokenInstance.balanceOf(bobAddress);
      vestedAmount = await CoreInstance.getVestedAmount(1, bobAddress);
      withdrawableAmount = await CoreInstance.getWithdrawableAmount(
        1,
        bobAddress
      );

      // Bob's new balance should be equal to withdrawableAmount claimed
      expect(bobBalance).to.equal(expectedBalance);
      expect(withdrawableAmount).to.be.within(
        0,
        expectedWithdrawable.div(constants.DEPLOY.ERR_TOL_DIV)
      );
      expect(vestedAmount).to.be.closeTo(
        expectedVested,
        expectedVested.div(constants.DEPLOY.ERR_TOL_DIV)
      );

      // Fast forward 51 days - past end of vesting
      await fastForward(51 * constants.TEST.oneDay);

      vestedAmount = await CoreInstance.getVestedAmount(1, bobAddress);
      withdrawableAmount = await CoreInstance.getWithdrawableAmount(
        1,
        bobAddress
      );

      expectedWithdrawable = totalAmount.sub(
        totalFeeOnAmount(totalAmount).add(expectedBalance)
      );
      //   expectedWithdrawable = afterFee(totalAmount.sub(expectedBalance));
      expect(withdrawableAmount).to.be.closeTo(
        expectedWithdrawable,
        expectedWithdrawable.div(constants.DEPLOY.ERR_TOL_DIV)
      );
      expect(vestedAmount).to.equal(totalAmount);

      // Claim rest of tokens
      await CoreInstance.connect(bob).claimVestedTokens(1, withdrawableAmount);

      bobBalance = await TokenInstance.balanceOf(bobAddress);
      vestedAmount = await CoreInstance.getVestedAmount(1, bobAddress);
      withdrawableAmount = await CoreInstance.getWithdrawableAmount(
        1,
        bobAddress
      );

      expect(withdrawableAmount).to.be.within(
        0,
        expectedWithdrawable.div(constants.DEPLOY.ERR_TOL_DIV)
      );
      expect(vestedAmount).to.equal(totalAmount);
      expect(bobBalance).to.equal(afterFee(totalAmount));
    });

    // SCENARIO TEST 2
    // - ETH vesting
    // - 5 recipients (100 ETH each)
    // - 100, 200, 300, 400, 500 day vesting periods
    // - Each recipient claims every 100 days

    it("SCEN 2 - ETH, 5 recipients, 100 - 500 day vests, claims every 100 days", async () => {
      // TODO
    });

    // SCENARIO TEST 3
    // - New token (TEST2)
    // - 3 recipients (100 TEST2 each)
    // - 300 day vesting periods each
    // - All accounts removed at 200 days
    // - Recipient 1 claims at 100 days, recipient 2 at 200 days, recipient 3 never
    // - All recipients can claim vested amount after removal
    // - Non-vested amount is returned to admin

    it("SCEN 3 - New Token, 3 recipients, all acounts removed before end", async () => {
      // TODO
    });

    // SCENARIO TEST 4
    // - ETH
    // - 2 recipients (100 ETH each)
    // - 1 year vesting periods
    // - Recipient 1 removed and Recipient 3 added at 6 months
    // - All 3 recipients only claim at end of vesting
    // - Non-vested amount for Recipient 1 is returned to admin

    it("SCEN 4 - ETH, 3 recipients, 1 year vesting, 1 removed, 1 added at 6 months", async () => {
      // TODO
    });
  });
});
