// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

// ------------------------------------------ //
//         IVestStrategyLinear v0.1           //
// ------------------------------------------ //

/**
    @title IVestStrategyLinear
 */
interface IVestingStrategy {
	function createVestingBox() external;

	function getClaimableTokens(uint256 vBoxID, address account) external view returns (uint256);

	function registerTokenWithdraw(
		uint256 vBoxID,
		address account,
		uint256 amount
	) external;
}
