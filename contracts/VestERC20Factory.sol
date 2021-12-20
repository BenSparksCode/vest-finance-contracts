// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import '@openzeppelin/contracts/access/Ownable.sol';

import './VestERC20.sol';

contract VestERC20Factory is Ownable {
	address public VEST_CORE;

	constructor() {}

	function createERC20(
		string calldata _tokenName,
		string calldata _tokenSymbol,
		uint256 _tokenTotalSupply
	) external onlyCore returns (address) {
		VestERC20 newToken = new VestERC20(_tokenName, _tokenSymbol, _tokenTotalSupply);
		return address(newToken);
	}

	function setCoreAddress(address _core) external onlyOwner {
		require(_core != address(0), 'FACTORY: Core not address zero');
		VEST_CORE = _core;
	}

	modifier onlyCore() {
		require(msg.sender == VEST_CORE);
		_;
	}
}
