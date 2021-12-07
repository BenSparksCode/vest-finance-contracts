const { ethers } = require('hardhat');
const { BigNumber } = require("@ethersproject/bignumber");
const { constants } = require("./TestConstants")

const ERC20_ABI = require("../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json")
const SushiRouter_ABI = require("../artifacts/contracts/interfaces/IUniswapV2Router02.sol/IUniswapV2Router02.json")

// const SushiRouter = new ethers.Contract(
//     constants.CONTRACTS.SUSHI.ROUTER,
//     SushiRouter_ABI.abi,
//     ethers.provider
// )

// Gets the time of the last block.
const currentTime = async () => {
    const { timestamp } = await ethers.provider.getBlock('latest');
    return timestamp;
};

// Increases the time in the EVM.
// seconds = number of seconds to increase the time by
const fastForward = async (seconds) => {
    await ethers.provider.send("evm_increaseTime", [seconds])
    await ethers.provider.send("evm_mine", [])
};

const toJSNum = (bigNum) => {
    return parseInt(bigNum.toString())
}

const burnTokenBalance = async (signer, tokenContract) => {
    const addr = await signer.getAddress()
    const bal = await tokenContract.balanceOf(addr)
    tokenContract.connect(signer).transfer("0x000000000000000000000000000000000000dEaD", bal)
}


module.exports = {
    currentTime: currentTime,
    fastForward: fastForward,
    burnTokenBalance: burnTokenBalance,
}