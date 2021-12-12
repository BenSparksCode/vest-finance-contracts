// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

// ------------------------------------------ //
//                VestCore v0.1               //
// ------------------------------------------ //

/**
    @title VestCore
 */
contract VestCore is Ownable {
	uint256 public constant SCALE = 1e18;
	uint25 public fee = 1e15; // 0.1% fee

	struct VestingToken {
		address token;
		address[] recipients;
		uint256[] amounts;
		uint256[] startTimes;
		uint256[] endTimes;
	}

	mapping(uint256 => VestingToken) private vestingTokens;
	// isAdminOfVestingToken[account][vestingTokenId] = true/false
	mapping(address => mapping(uint256 => bool)) private isAdminOfVestingToken;

	constructor() {}

	// TODO better name?
	function createVestingAgreement(
		address _token,
		address[] _recipients,
		uint256[] _amounts,
		uint256[] _startTimes,
		uint256[] _endTimes
	) returns (bool success) {
		// TODO
		return true;
	}
}
