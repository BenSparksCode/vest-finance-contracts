// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import './VestERC20.sol';

contract VestERC20Factory {
	address public VEST_CORE;

	constructor(address _core) {
		VEST_CORE = _core;
	}

	function createERC20() external onlyCore {}

	modifier onlyCore() {
		require(msg.sender == VEST_CORE);
		_;
	}
}
