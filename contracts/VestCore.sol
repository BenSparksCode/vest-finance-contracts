// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

// ------------------------------------------ //
//                VestCore v0.1               //
// ------------------------------------------ //

// TODO Natspec all functions

/**
    @title VestCore
 */
contract VestCore is Ownable {
	uint256 public constant SCALE = 1e18;
	uint256 public fee = 1e15; // 0.1% fee

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

	// ------------------------------------------ //
	//                  EVENTS                    //
	// ------------------------------------------ //

	event VestingBoxCreated();

	// ------------------------------------------ //
	//                CONSTRUCTOR                 //
	// ------------------------------------------ //

	constructor() {}

	// ------------------------------------------ //
	//              PUBLIC FUNCTIONS              //
	// ------------------------------------------ //

	function createVestingBoxWithExistingToken(
		address _token,
		uint256 _totalAmount,
		uint256[] calldata _amounts,
		address[] calldata _recipients,
		uint256[] calldata _startTimes,
		uint256[] calldata _endTimes
	) public returns (bool success) {
		require(_token != address(0));
		require(_totalAmount > 0);
		require(_recipients.length == _amounts.length);
		require(_recipients.length == _startTimes.length);
		require(_recipients.length == _endTimes.length);

		VestingBox memory vBox = VestingBox(_token, _recipients, _amounts, _startTimes, _endTimes);

		vBoxCount++;

		vBoxes[vBoxCount] = vBox;

		// TODO pull in totalAmount of tokens, take fee here

		// TODO
		return true;
	}

	function createVestingBoxWithNewToken(
		address _token,
		uint256 _totalAmount,
		uint256[] calldata _amounts,
		address[] calldata _recipients,
		uint256[] calldata _startTimes,
		uint256[] calldata _endTimes
	) public returns (bool success) {
		// TODO
		return true;
	}

	// TODO
	function createVestingBoxWithETH() public returns (bool success) {
		// TODO
		return true;
	}

	// TODO if error in start/end times, all tokens withdrawable

	// ------------------------------------------ //
	//           INTERNAL FUNCTIONS               //
	// ------------------------------------------ //

	// TODO
	function _createVestingBox() internal returns (bool success) {
		vBoxCount++;
		// TODO

		emit VestingBoxCreated(vBoxCount, _token, msg.sender);

		return true;
	}

	// ------------------------------------------ //
	//             VIEW FUNCTIONS                 //
	// ------------------------------------------ //

	function getVestingBox(uint256 _vestingBoxId) public view returns (VestingBox memory vestingBox) {
		require(_vestingBoxId > 0);
		require(_vestingBoxId <= vBoxCount);

		return vBoxes[_vestingBoxId];
	}

	// ------------------------------------------ //
	//                MODIFIERS                   //
	// ------------------------------------------ //
}
