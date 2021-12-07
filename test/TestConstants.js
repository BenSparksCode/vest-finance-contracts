const { BigNumber } = require("@ethersproject/bignumber");
const { ethers } = require("hardhat");

const CONSTANTS = {
    MUMBAI: {
        DAI: "0x001B3B4d0F3714Ca98ba10F6042DaEbF0B1B7b6F",
        aDAI: "0x639cB7b21ee2161DF9c882483C9D55c90c20Ca3e",
        LINK: "0x326C977E6efc84E512bB9C30f76E30c160eD06FB",
        ChainlinkVRFCoordinator: "0x8C7382F9D8f56b33781fE506E897a4F1e2d17255",
        ChainlinkKeyHash: "0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4",
        AaveLendingPool: "0x9198F13B08E299d85E096929fA9781A1E3d5d827",
        ZoraMedia: "0xabEFBc9fD2F806065b4f3C237d4b59D9A97Bcac7",
        ZoraMarket: "0xE5BFAB544ecA83849c53464F85B7164375Bdaac1",
    },
    POLYGON: {
        DAI: "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063",
        aDAI: "0x27F8D03b3a2196956ED754baDc28D73be8830A6e",
        LINK: "0xb0897686c545045afc77cf20ec7a532e3120e0f1",
        ChainlinkVRFCoordinator: "0x3d2341ADb2D31f1c5530cDC622016af293177AE0",
        ChainlinkKeyHash: "0xf86195cf7690c55907b2b611ebb7343a6f649bff128701cc542f0569e2c549da",
        AaveLendingPool: "0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf",
        ZoraMedia: "0x6953190AAfD8f8995e8f47e8F014d0dB83E92300",
        ZoraMarket: "0xE20bd7dC76e09AEBC2A9A732AB6AEE616c5a17Eb",
    },
    SHIP: {
        decimals: 18,
        total: 100000000,               //  100 million
        hackathonAirdrop: 2000000,      //  2 million
        mainnetAirdrop: 8000000,        //  8 million
        strategicPartners: 16000000,    //  16 million
        stakingRewards: 20000000,       //  20 million
        teamVesting: 24000000,          //  24 million
        daoTreasury: 30000000           //  30 million
    },
    DEPLOY: {
        SHIP:{
            name: "SHIP",
            symbol: "SHIP",
            totalSupply: ethers.utils.parseUnits("100000000", "ether") //100 million with 18 decimals
        },
        FERRY: {
            annualFee: ethers.utils.parseUnits("24", "ether"), //$24 per year to start
            maxMintedNFTs: 50000,
            maxMembershipPeriod: 2*365*86400, // 2 years = 2 * 365 days * 86400 seconds per day
            nftThreshold: ethers.utils.parseUnits("1", "ether"), //$1 Will cost less than $0.01 in LINK for random num
        },
        NFT_MINTER: {
            vrfFee: 100000000000000,
        },
        TOKENS: {
            daiApproveAmount: ethers.utils.parseUnits("30", "ether"),
            linkToMinterAmount: 1000000000000000 // 10 * 0.0001 VRF fee
        }
    }
}


module.exports = {
    constants: CONSTANTS
}