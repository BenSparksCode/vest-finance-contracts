// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import '@openzeppelin/contracts/access/Ownable.sol';
import './interfaces/IVestERC20Factory.sol';
import './VestERC20.sol';

import 'hardhat/console.sol'; //TODO remove

contract VestERC20Factory is IVestERC20Factory, Ownable {
	address public VEST_CORE;

	constructor() {}

	function createERC20(
		string calldata _tokenName,
		string calldata _tokenSymbol,
		uint256 _tokenTotalSupply
	) external onlyCore returns (address) {
		VestERC20 newToken = new VestERC20(_tokenName, _tokenSymbol, _tokenTotalSupply, VEST_CORE);
		return address(newToken);
	}

	function setCoreAddress(address _core) external onlyOwner {
		require(_core != address(0), 'FACTORY: CORE NOT ZERO ADDRESS');
		VEST_CORE = _core;
	}

	modifier onlyCore() {
		require(msg.sender == VEST_CORE);
		_;
	}
}
