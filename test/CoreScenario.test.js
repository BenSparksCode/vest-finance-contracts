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

  describe("Scenarios", function () {
    it.only("Existing token, 1 recipient, 100 day vest, 2 claims", async () => {
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

      let contractBal = await TokenInstance.balanceOf(CoreInstance.address);
      console.log("contract bal: \t\t\t\t", contractBal.toString());
      console.log(
        "contract bal less fees: \t\t",
        afterFee(contractBal).toString()
      );
      console.log(
        "withdrawable (fees already off): \t",
        withdrawableAmount.toString()
      );

      // Bob withdraws max withdrawable (half of total)
      await CoreInstance.connect(bob).claimVestedTokens(1, withdrawableAmount);

      contractBal = await TokenInstance.balanceOf(CoreInstance.address);
      withdrawableAmount = await CoreInstance.getWithdrawableAmount(
        1,
        bobAddress
      );
      console.log("contract bal: \t\t\t\t", contractBal.toString());
      console.log(
        "contract bal less fees: \t\t",
        afterFee(contractBal).toString()
      );
      console.log(
        "withdrawable (fees already off): \t",
        withdrawableAmount.toString()
      );

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

      expectedWithdrawable = afterFee(totalAmount.sub(expectedBalance));
      expect(withdrawableAmount).to.be.closeTo(
        expectedWithdrawable,
        expectedWithdrawable.div(constants.DEPLOY.ERR_TOL_DIV)
      );
      expect(vestedAmount).to.equal(totalAmount);

      contractBal = await TokenInstance.balanceOf(CoreInstance.address);
      console.log("contract bal: \t\t\t\t", contractBal.toString());
      console.log(
        "contract bal less fees: \t\t",
        contractBal
          .sub(
            totalAmount.mul(constants.DEPLOY.fee).div(constants.DEPLOY.SCALE)
          )
          .toString()
      );
      console.log(
        "withdrawable (fees already off): \t",
        withdrawableAmount.toString()
      );

      // Claim rest of tokens
      await CoreInstance.connect(bob).claimVestedTokens(1, withdrawableAmount);

      bobBalance = await TokenInstance.balanceOf(bobAddress);
      vestedAmount = await CoreInstance.getVestedAmount(1, bobAddress);
      withdrawableAmount = await CoreInstance.getWithdrawableAmount(
        1,
        bobAddress
      );

      expect(withdrawableAmount).to.be.closeTo(
        0,
        expectedWithdrawable.div(constants.DEPLOY.ERR_TOL_DIV)
      );
      expect(vestedAmount).to.equal(totalAmount);
      expect(bobBalance).to.equal(afterFee(totalAmount));
    });
  });
});
