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
// TODO check if all return types are needed

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
		address[] admins;
		address[] recipients;
	}

	// For mapping account => VestingBox data to avoid arrays
	struct VestingBoxAccount {
		uint256 amount;
		uint256 withdrawn;
		uint128 startTime;
		uint128 endTime;
	}

	// For storing entire vBox data per vBox ID
	mapping(uint256 => VestingBox) private vBoxes;
	// For looking up specific account's data within vBox of given ID
	// vBoxID => account => VestingBoxAccount
	mapping(uint256 => mapping(address => VestingBoxAccount)) private vBoxAccounts;
	// isAdminOfVBox[vBoxId][account] = true/false
	mapping(uint256 => mapping(address => bool)) private isAdminOfVBox;
	// All token and ETH balances held for vesting boxes (excl. fees)
	mapping(address => uint256) private assetsHeldForVesting;

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
		uint256 _totalAmount,
		VestingBox calldata _vBox,
		VestingBoxAccount[] calldata _vBoxAccounts
	) public returns (bool success) {
		require(_vBox.token != address(0), 'VEST: ZERO ADDR NOT TOKEN');
		require(_totalAmount > 0, 'VEST: CANNOT VEST 0 AMOUNT');
		require(_vBox.recipients.length > 0, 'VEST: NO RECIPIENTS');
		require(_vBox.recipients.length == _vBoxAccounts.length, 'VEST: WRONG ACCOUNTS ARRAY LEN');

		uint256 amountsSum = 0;
		for (uint256 i = 0; i < _vBoxAccounts.length; i++) {
			amountsSum += _vBoxAccounts[i].amount;
		}

		require(amountsSum == _totalAmount, 'VEST: AMOUNTS DONT SUM TO TOTAL');

		// transfer tokens to be vested from msg.sender to Core
		require(
			IERC20(_vBox.token).transferFrom(msg.sender, address(this), _totalAmount),
			'VEST: TOKEN TRANSFER FAILED'
		);

		vBoxCount++;
		vBoxes[vBoxCount] = _vBox;

		for (uint256 i = 0; i < _vBoxAccounts.length; i++) {
			vBoxAccounts[vBoxCount][_vBox.recipients[i]] = _vBoxAccounts[i];
		}

		assetsHeldForVesting[_vBox.token] += _totalAmount;

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

	function claimVestedTokens(uint256 _vBoxId, uint256 _amountToClaim) public returns (bool success) {
		// withdrawableAmount = total vested - withdrawn
		uint256 withdrawableAmount = getWithdrawableAmount(_vBoxId, msg.sender);
		require(withdrawableAmount >= _amountToClaim, 'VEST: WITHDRAWABLE TOO LOW');

		// Send tokens to recipient
		_withdrawFromVBox(_vBoxId, _amountToClaim);

		return true;
	}

	// TODO if error in start/end times, all tokens withdrawable

	// TODO function addRecipientToVestingBox() - deposit more tokens and add a new person

	// ------------------------------------------ //
	//           ONLY-OWNER FUNCTIONS             //
	// ------------------------------------------ //

	function withdrawTokenFees(
		address _token,
		uint256 _amount,
		address _to
	) public onlyOwner {
		require(
			IERC20(_token).balanceOf(address(this)) - assetsHeldForVesting[_token] >= _amount,
			'VEST: AMOUNT TOO HIGH'
		);
		IERC20(_token).transfer(_to, _amount);
	}

	function withdrawETHFees(uint256 _amount, address _to) public onlyOwner {
		require(address(this).balance - assetsHeldForVesting[ETH] >= _amount, 'VEST: AMOUNT TOO HIGH');
		(bool sent, ) = _to.call{ value: _amount }('');
		require(sent, 'VEST: ETH TRANSFER FAILED');
	}

	function setFee(uint256 _fee) public onlyOwner {
		require(_fee <= SCALE, 'VEST: FEE MUST BE < 100%');
		fee = _fee;
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

	function _withdrawFromVBox(uint256 _vBoxId, uint256 _amountToWithdraw) internal returns (bool success) {
		bool sent = false;
		// TODO check here for withdraw limits?
		vBoxAccounts[_vBoxId][msg.sender].withdrawn += _amountToWithdraw;
		if (vBoxes[_vBoxId].token == ETH) {
			(sent, ) = msg.sender.call{ value: _amountToWithdraw }('');
		} else {
			sent = IERC20(vBoxes[_vBoxId].token).transfer(msg.sender, _amountToWithdraw);
		}
		require(sent, 'VEST: WITHDRAW FAILED');
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

	// NOTE: Use 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE as token to get ETH fees
	function getProtocolFeesEarned(address _token) public view returns (uint256) {
		if (_token == ETH) {
			return address(this).balance - assetsHeldForVesting[ETH];
		} else {
			return IERC20(_token).balanceOf(address(this)) - assetsHeldForVesting[_token];
		}
	}

	// returns total vested - withdrawn
	function getWithdrawableAmount(uint256 _vBoxId, address _account) public view returns (uint256) {
		if (block.timestamp >= vBoxAccounts[_vBoxId][_account].endTime) {
			return vBoxAccounts[_vBoxId][_account].amount - vBoxAccounts[_vBoxId][_account].withdrawn;
		}

		uint256 vestedTime = block.timestamp - vBoxAccounts[_vBoxId][_account].startTime;
		uint256 totalTime = vBoxAccounts[_vBoxId][_account].endTime - vBoxAccounts[_vBoxId][_account].startTime;
		uint256 vestedAmount = (vBoxAccounts[_vBoxId][_account].amount * vestedTime * SCALE) / (totalTime * SCALE);

		return vestedAmount - vBoxAccounts[_vBoxId][_account].withdrawn;
	}

	// ------------------------------------------ //
	//                MODIFIERS                   //
	// ------------------------------------------ //

	modifier isVestingBoxAdmin(uint256 _vBoxId, address _account) {
		require(isAdminOfVBox[_vBoxId][_account], 'VEST: NOT VBOX ADMIN');
		_;
	}

	modifier hasAmountInBox(uint256 _vBoxId, address _account) {
		require(vBoxAccounts[_vBoxId][_account].amount > 0, 'VEST: NO AMOUNT IN BOX');
		_;
	}
}
