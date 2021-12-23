// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import './BaseERC20.sol';

contract VestERC20 is BaseERC20 {
	constructor(
		string memory _name,
		string memory _symbol,
		uint256 _totalSupply,
		address mintRecipient
	) BaseERC20(_name, _symbol, 18) {
		_mint(mintRecipient, _totalSupply);
	}
}
