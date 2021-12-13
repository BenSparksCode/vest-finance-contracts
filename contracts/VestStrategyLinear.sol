// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import './IVestingStrategy.sol';

// ------------------------------------------ //
//          VestStrategyLinear v0.1           //
// ------------------------------------------ //

// TODO Natspec all functions

/**
    @title VestStrategyLinear
 */
contract VestStrategyLinear is IVestingStrategy {
	uint256 vBoxCount = 0;

	// Stores all properties of a vesting agreement
	// vBox for short in var naming
	struct VestingBox {
		address token;
		address[] recipients;
		uint256[] amounts;
		uint256[] startTimes;
		uint256[] endTimes;
	}

	mapping(uint256 => VestingBox) private vBoxes;
	// isAdminOfVBox[account][vBoxId] = true/false
	mapping(address => mapping(uint256 => bool)) private isAdminOfVBox;

	uint256 public constant SCALE = 1e18;

	// ------------------------------------------ //
	//                  EVENTS                    //
	// ------------------------------------------ //

	event VestingBoxCreated(uint256 vBoxID, address token, address creator);

	// ------------------------------------------ //
	//                CONSTRUCTOR                 //
	// ------------------------------------------ //

	constructor() {}
}
