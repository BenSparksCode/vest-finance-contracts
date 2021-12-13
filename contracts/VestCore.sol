// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import './VestERC20.sol';

// ------------------------------------------- //
//             🦺 VestCore v0.1 🦺             //
// ------------------------------------------ //

// TODO Natspec all functions
// TODO make sure all vars are used efficiently (mappings vs arrays)

/**
    @title VestCore
 */
contract VestCore is Ownable {
	uint256 public constant SCALE = 1e18;
	uint256 public fee = 1e15; // 0.1% fee
	uint256 public vBoxCount = 0;

	address public ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

	// Stores all properties of a vesting agreement
	// vBox for short in var naming
	struct VestingBox {
		address token;
		address[] recipients;
		uint256[] amounts;
		uint256[] withdrawn;
		uint256[] startTimes;
		uint256[] endTimes;
	}

	// For mapping account => VestingBox data to avoid arrays
	struct VestingBoxAccount {
		uint256 amount;
		uint256 withdrawn;
		uint256 startTime;
		uint256 endTime;
	}

	// For storing entire vBox data per vBox ID
	mapping(uint256 => VestingBox) private vBoxes;
	// For looking up specific account's data within vBox of given ID
	// vBoxID => account => VestingBoxAccount
	mapping(uint256 => mapping(address => VestingBoxAccount)) private vBoxAccounts;
	// For all fees earned across all tokens
	mapping(address => uint256) private tokenFeesEarned;
	// isAdminOfVBox[account][vBoxId] = true/false
	mapping(address => mapping(uint256 => bool)) private isAdminOfVBox;

	// ------------------------------------------ //
	//                  EVENTS                    //
	// ------------------------------------------ //

	event VestingBoxCreated(uint256 vBoxID, address token, address creator);

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
		address[] calldata _recipients,
		uint256[] calldata _amounts,
		uint256[] calldata _startTimes,
		uint256[] calldata _endTimes
	) public returns (bool success) {
		uint256 arrayLength = _recipients.length;
		require(_token != address(0), 'VEST: ZERO ADDR NOT TOKEN');
		require(_totalAmount > 0, 'VEST: CANNOT VEST 0 AMOUNT');
		require(arrayLength > 0, 'VEST: NO RECIPIENTS');
		require(arrayLength == _amounts.length, 'VEST: WRONG AMOUNTS ARRAY LENGTH');
		require(arrayLength == _startTimes.length, 'VEST: WRONG START TIMES LENGTH');
		require(arrayLength == _endTimes.length, 'VEST: WRONG END TIMES LENGTH');

		uint256 amountsSum = 0;
		for (uint256 i = 0; i < arrayLength; i++) {
			amountsSum += _amounts[i];
		}

		require(amountsSum == _totalAmount, 'VEST: AMOUNTS DONT SUM TO TOTAL');

		// transfer tokens to be vested from msg.sender to Core
		require(IERC20(_token).transferFrom(msg.sender, address(this), _totalAmount), 'VEST: TOKEN TRANSFER FAILED');

		VestingBox memory vBox = VestingBox(
			_token,
			_recipients,
			_amounts,
			new uint256[](arrayLength), //withdrawn
			_startTimes,
			_endTimes
		);

		vBoxCount++;

		vBoxes[vBoxCount] = vBox;

		for (uint256 i = 0; i < arrayLength; i++) {
			vBoxAccounts[vBoxCount][_recipients[i]] = VestingBoxAccount(_amounts[i], 0, _startTimes[i], _endTimes[i]);
		}

		return true;
	}

	// function createVestingBoxWithNewToken(
	// 	address _token,
	// 	uint256 _totalAmount,
	// 	uint256[] calldata _amounts,
	// 	address[] calldata _recipients,
	// 	uint256[] calldata _startTimes,
	// 	uint256[] calldata _endTimes
	// ) public returns (bool success) {
	// 	// TODO
	// 	return true;
	// }

	// TODO
	// function createVestingBoxWithETH() public returns (bool success) {
	// 	// TODO
	// 	return true;
	// }

	// TODO if error in start/end times, all tokens withdrawable

	// TODO function addRecipientToVestingBox() - deposit more tokens and add a new person

	// ------------------------------------------ //
	//           ONLY OWNER FUNCTIONS             //
	// ------------------------------------------ //

	function withdrawTokenFees(
		address _token,
		uint256 _amount,
		address _to
	) public onlyOwner {
		require(tokenFeesEarned[_token] >= _amount, 'VEST: AMOUNT TOO HIGH');
		tokenFeesEarned[_token] -= _amount;
		IERC20(_token).transfer(_to, _amount);
	}

	function withdrawETHFees(uint256 _amount, address _to) public onlyOwner {
		require(address(this).balance >= _amount, 'VEST: AMOUNT TOO HIGH');
		tokenFeesEarned[ETH] -= _amount;
		(bool sent, ) = _to.call{ value: _amount }('');
		require(sent, 'VEST: ETH TRANSFER FAILED');
	}

	// ------------------------------------------ //
	//            INTERNAL FUNCTIONS              //
	// ------------------------------------------ //

	// TODO
	// function _createVestingBox() internal returns (bool success) {
	// 	vBoxCount++;
	// 	// TODO

	// 	emit VestingBoxCreated(vBoxCount, _token, msg.sender);

	// 	return true;
	// }

	function _createERC20() internal returns (bool success) {
		// TODO

		// deploy token (no owner)
		// in constructor, mint total vesting amount to Core
		// all recipients can recover amounts from Core

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

	function getProtocolFeesEarned(address _token) public view returns (uint256) {
		return tokenFeesEarned[_token];
	}

	// ------------------------------------------ //
	//                MODIFIERS                   //
	// ------------------------------------------ //

	modifier hasVestedAmountInBox(address _account) {
		// TODO
		_;
	}
}
