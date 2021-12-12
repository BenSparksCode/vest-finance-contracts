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

	uint256 vTokenCount = 0;

	// VToken = Vesting Token
	struct VToken {
		address token;
		address[] recipients;
		uint256[] amounts;
		uint256[] startTimes;
		uint256[] endTimes;
	}

	mapping(uint256 => VToken) private vTokens;
	// isAdminOfVToken[account][vTokenId] = true/false
	mapping(address => mapping(uint256 => bool)) private isAdminOfVToken;

	constructor() {}

	// TODO better name?
	function createVestingAgreement(
		address _token,
		uint256 _totalAmount,
		uint256[] _amounts,
		address[] _recipients,
		uint256[] _startTimes,
		uint256[] _endTimes
	) returns (bool success) {
		require(_token != address(0));
		require(_totalAmount > 0);
		require(_recipients.length == _amounts.length);
		require(_recipients.length == _startTimes.length);
		require(_recipients.length == _endTimes.length);

		VestingToken memory vToken = VestingToken(_token, _recipients, _amounts, _startTimes, _endTimes);

		vTokenCount++;

		vestingTokens[vTokenCount] = vToken;

		// TODO pull in totalAmount of tokens, take fee here

		// TODO
		return true;
	}

	// TODO if error in start/end times, all tokens withdrawable
}
