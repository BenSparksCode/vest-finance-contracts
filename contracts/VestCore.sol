// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import './interfaces/IVestERC20Factory.sol';
import './VestERC20.sol';

import 'hardhat/console.sol'; //TODO remove

// ------------------------------------------- //
//             🦺 VestCore v0.1 🦺             //
// ------------------------------------------ //

// TODO Natspec all functions

/**
    @title VestCore
 */
contract VestCore is Ownable {
	uint256 public constant SCALE = 1e18;
	uint256 public fee = 1e15; // 0.1% fee
	uint256 public vBoxCount = 0;

	IVestERC20Factory public tokenFactory;
	address public ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

	// Stores global variables of vBox
	struct VestingBox {
		address token;
		address creator;
	}

	// Stores per-address variables of vBox
	struct VestingBoxAccount {
		uint256 amount;
		uint256 withdrawn;
		uint128 startTime;
		uint128 endTime;
	}

	// Not stored, defined for data structure passed in for vBox creation
	struct VestingBoxAddresses {
		address[] admins;
		address[] recipients;
	}

	// For storing entire vBox data per vBox ID
	mapping(uint256 => VestingBox) public vBoxes;
	// For looking up specific account's data within vBox of given ID
	// vBoxID => account => VestingBoxAccount
	mapping(uint256 => mapping(address => VestingBoxAccount)) public vBoxAccounts;
	// isAdminOfVBox[vBoxId][account] = true/false
	mapping(uint256 => mapping(address => bool)) public isAdminOfVBox;
	// All token and ETH balances held for vesting boxes (excl. fees)
	// NOTE: Use 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE as token to get ETH held
	mapping(address => uint256) public assetsHeldForVesting;

	// ------------------------------------------ //
	//                  EVENTS                    //
	// ------------------------------------------ //

	event VestingBoxCreated(uint256 indexed vBoxID, address indexed token, address creator, uint256 totalBoxAmount);
	event VestedTokensClaimed(uint256 indexed vBoxID, address indexed token, uint256 amountClaimed, address recipient);

	event VestingBoxAdminSet(uint256 indexed vBoxID, address account, bool isAdmin);

	event AccountAddedToVestingBox(
		uint256 indexed vBoxID,
		address indexed account,
		uint256 amount,
		uint128 startTime,
		uint128 endTime
	);
	event AccountRemovedFromVestingBox(
		uint256 indexed vBoxID,
		address indexed account,
		uint256 amountVested,
		uint256 amountForfeited
	);

	event FeesEarned(address token, uint256 feesEarned);
	event FeesWithdrawn(address token, uint256 feesWithdrawn, address _to);
	event FeeChanged(uint256 oldFee, uint256 newFee);

	event ERC20Created(address tokenAddress);

	// ------------------------------------------ //
	//                CONSTRUCTOR                 //
	// ------------------------------------------ //

	constructor() {}

	// ------------------------------------------ //
	//              PUBLIC FUNCTIONS              //
	// ------------------------------------------ //

	function createVestingBoxWithExistingToken(
		uint256 _totalAmount,
		VestingBox memory _vBox,
		VestingBoxAccount[] memory _vBoxAccounts,
		VestingBoxAddresses calldata _vBoxAddresses
	) external returns (bool) {
		return _createVestingBox(_totalAmount, _vBox, _vBoxAccounts, _vBoxAddresses, false);
	}

	// NOTE: _vBox token left blank, will be set to newly created token
	function createVestingBoxWithNewToken(
		uint256 _totalAmount,
		VestingBox memory _vBox,
		VestingBoxAccount[] memory _vBoxAccounts,
		VestingBoxAddresses calldata _vBoxAddresses,
		string calldata _tokenName,
		string calldata _tokenSymbol,
		uint256 _tokenTotalSupply
	) external returns (bool) {
		// creates new token and sets address in _vBox before creating vBox
		_vBox.token = _createERC20(_tokenName, _tokenSymbol, _tokenTotalSupply);
		return _createVestingBox(_totalAmount, _vBox, _vBoxAccounts, _vBoxAddresses, true);
	}

	function createVestingBoxWithETH(
		uint256 _totalAmount,
		VestingBox memory _vBox,
		VestingBoxAccount[] memory _vBoxAccounts,
		VestingBoxAddresses calldata _vBoxAddresses
	) external payable returns (bool) {
		_vBox.token = ETH;
		return _createVestingBox(_totalAmount, _vBox, _vBoxAccounts, _vBoxAddresses, false);
	}

	// check manual setting amounta and withdrawn don't cause claim exploits
	function claimVestedTokens(uint256 _vBoxId, uint256 _amountClaimedAfterFee) public returns (bool) {
		// withdrawableAmount = total vested - withdrawn
		uint256 withdrawableAmount = getWithdrawableAmount(_vBoxId, msg.sender);
		require(withdrawableAmount >= _amountClaimedAfterFee, 'VEST: NOT ENOUGH VESTED');

		// Send tokens to recipient
		_withdrawFromVBox(_vBoxId, _amountClaimedAfterFee);

		emit VestedTokensClaimed(_vBoxId, vBoxes[_vBoxId].token, _amountClaimedAfterFee, msg.sender);

		return true;
	}

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

		emit FeesWithdrawn(_token, _amount, _to);
	}

	function withdrawETHFees(uint256 _amount, address _to) public onlyOwner {
		require(address(this).balance - assetsHeldForVesting[ETH] >= _amount, 'VEST: AMOUNT TOO HIGH');
		(bool sent, ) = _to.call{ value: _amount }('');
		require(sent, 'VEST: ETH TRANSFER FAILED');

		emit FeesWithdrawn(ETH, _amount, _to);
	}

	function setFee(uint256 _fee) public onlyOwner {
		uint256 oldFee = fee;
		require(_fee < SCALE, 'VEST: FEE MUST BE < 100%');
		fee = _fee;

		emit FeeChanged(oldFee, _fee);
	}

	function setTokenFactory(IVestERC20Factory _newFactory) external onlyOwner {
		tokenFactory = _newFactory;
	}

	// ------------------------------------------ //
	//           BOX-ADMIN FUNCTIONS              //
	// ------------------------------------------ //

	function setVestingBoxAdmin(
		uint256 _vBoxId,
		address _account,
		bool _isAdmin
	) external onlyVestingBoxAdmin(_vBoxId, msg.sender) {
		isAdminOfVBox[_vBoxId][_account] = _isAdmin;
		emit VestingBoxAdminSet(_vBoxId, _account, _isAdmin);
	}

	function addAccountToVestingBox(
		uint256 _vBoxId,
		address _recipient,
		VestingBoxAccount memory _vBoxAccount
	) external onlyVestingBoxAdmin(_vBoxId, msg.sender) {
		// Cannot add if address already has vesting tokens in given vBox
		require(vBoxAccounts[_vBoxId][_recipient].amount == 0, 'VEST: ACCOUNT ALREADY IN BOX');

		// Check data in vBoxAccount is valid
		_checkVBoxAccountValid(_vBoxAccount);

		// pull new amount of token
		require(
			IERC20(vBoxes[_vBoxId].token).transferFrom(msg.sender, address(this), _vBoxAccount.amount),
			'VEST: TOKEN TRANSFER FAILED'
		);

		vBoxAccounts[_vBoxId][_recipient] = _vBoxAccount;
		assetsHeldForVesting[vBoxes[_vBoxId].token] += _vBoxAccount.amount;

		emit AccountAddedToVestingBox(
			_vBoxId,
			_recipient,
			_vBoxAccount.amount,
			_vBoxAccount.startTime,
			_vBoxAccount.endTime
		);
	}

	// NOTE: sends unvested tokens back to vBox creator
	function removeAccountFromVestingBox(uint256 _vBoxId, address _account)
		external
		onlyVestingBoxAdmin(_vBoxId, msg.sender)
	{
		// Store vBox and vBoxAccount in memory for fewer SLOADs
		VestingBoxAccount memory vBoxAcc = vBoxAccounts[_vBoxId][_account];
		VestingBox memory vBox = vBoxes[_vBoxId];

		require(vBoxAcc.endTime > block.timestamp, 'VEST: ALREADY FULLY VESTED');

		uint256 originalAmount = vBoxAcc.amount;

		// Set amount to current vested amount
		vBoxAcc.amount = getVestedAmount(_vBoxId, _account);

		// Set endtime to now
		vBoxAcc.endTime = uint128(block.timestamp);

		// Calculate amount forfeited before fee is taken - this gross amount will be reported in event below
		uint256 amountForfeited = originalAmount - vBoxAcc.amount;

		// Take fee and calc amount to send back after fee
		uint256 amountForfeitedAfterFee = _takeFee(vBox.token, amountForfeited);
		assetsHeldForVesting[vBox.token] -= amountForfeitedAfterFee;

		// Send remaining locked tokens back to vBox creator
		require(IERC20(vBox.token).transfer(vBox.creator, amountForfeitedAfterFee), 'VEST: FORFEIT TOKENS FAILED');

		emit AccountRemovedFromVestingBox(_vBoxId, _account, vBoxAcc.amount, amountForfeited);
	}

	// ------------------------------------------ //
	//            INTERNAL FUNCTIONS              //
	// ------------------------------------------ //

	function _createERC20(
		string calldata _tokenName,
		string calldata _tokenSymbol,
		uint256 _tokenTotalSupply
	) internal returns (address) {
		address newToken = tokenFactory.createERC20(_tokenName, _tokenSymbol, _tokenTotalSupply);

		emit ERC20Created(newToken);
		return newToken;
	}

	function _createVestingBox(
		uint256 _totalAmount,
		VestingBox memory _vBox,
		VestingBoxAccount[] memory _vBoxAccounts,
		VestingBoxAddresses calldata _vBoxAddresses,
		bool _newToken
	) internal returns (bool) {
		require(_totalAmount > 0, 'VEST: CANNOT VEST 0 AMOUNT');
		require(_vBoxAddresses.recipients.length > 0, 'VEST: NO RECIPIENTS');
		require(_vBoxAddresses.recipients.length == _vBoxAccounts.length, 'VEST: WRONG ACCOUNTS ARRAY LEN');

		if (_vBox.token == ETH) {
			require(msg.value >= _totalAmount, 'VEST: ETH AMOUNT TOO LOW');
		}

		uint256 amountsSum = 0;
		for (uint256 i = 0; i < _vBoxAccounts.length; i++) {
			amountsSum += _vBoxAccounts[i].amount;
		}

		require(amountsSum == _totalAmount, 'VEST: AMOUNTS DONT SUM TO TOTAL');

		// Only pull tokens if not ETH box and not new token (new tokens get minted to core on creation)
		if (_vBox.token != ETH && !_newToken) {
			require(
				IERC20(_vBox.token).transferFrom(msg.sender, address(this), _totalAmount),
				'VEST: TOKEN TRANSFER FAILED'
			);
		}

		vBoxCount++;
		vBoxes[vBoxCount] = _vBox;

		// Set up all recipient vBoxAccounts
		for (uint256 i = 0; i < _vBoxAccounts.length; i++) {
			_checkVBoxAccountValid(_vBoxAccounts[i]);
			vBoxAccounts[vBoxCount][_vBoxAddresses.recipients[i]] = _vBoxAccounts[i];
		}

		// Add all admins to isAdminOfVBox
		for (uint256 i = 0; i < _vBoxAccounts.length; i++) {
			isAdminOfVBox[vBoxCount][_vBoxAddresses.admins[i]] = true;
		}

		// Account for increase in assets held for vesting
		assetsHeldForVesting[_vBox.token] += _totalAmount;

		emit VestingBoxCreated(vBoxCount, _vBox.token, msg.sender, _totalAmount);

		return true;
	}

	function _withdrawFromVBox(uint256 _vBoxId, uint256 _amountAfterFee) internal returns (bool success) {
		bool sent = false;
		address tokenWithdrawn = vBoxes[_vBoxId].token;
		uint256 amountBeforeFee = calcBeforeFeeAmount(_amountAfterFee);

		// Take fee proportional to requested withdraw amount before sending
		_takeFee(tokenWithdrawn, amountBeforeFee);

		// Account for decrease in assets held - will revert if underflow (not enough for withdraw)
		assetsHeldForVesting[tokenWithdrawn] -= _amountAfterFee;
		// Increase vBoxAcc.withdrawn by (amount sent to user + fee taken)
		vBoxAccounts[_vBoxId][msg.sender].withdrawn += amountBeforeFee;
		if (tokenWithdrawn == ETH) {
			(sent, ) = msg.sender.call{ value: _amountAfterFee }('');
		} else {
			sent = IERC20(tokenWithdrawn).transfer(msg.sender, _amountAfterFee);
		}
		require(sent, 'VEST: WITHDRAW FAILED');
		return true;
	}

	function _checkVBoxAccountValid(VestingBoxAccount memory _vBoxAccount) internal {
		require(_vBoxAccount.startTime < _vBoxAccount.endTime, 'VEST: START TIME AFTER END TIME');
		require(_vBoxAccount.endTime > block.timestamp, 'VEST: END TIME IN THE PAST');
		require(_vBoxAccount.amount > 0, 'VEST: CANNOT VEST 0 AMOUNT');
	}

	// Calculates fee on token and amount, accounts, and returns amount after fee
	function _takeFee(address _token, uint256 _beforeFeeAmount) internal returns (uint256) {
		// If fee is 0, skip calcs and return whole _beforeFeeAmount
		if (fee == 0) {
			return _beforeFeeAmount;
		}
		uint256 afterFeeAmount = calcAfterFeeAmount(_beforeFeeAmount);
		uint256 feeTaken = _beforeFeeAmount - afterFeeAmount;
		assetsHeldForVesting[_token] -= feeTaken;

		emit FeesEarned(_token, feeTaken);
		return afterFeeAmount;
	}

	// ------------------------------------------ //
	//             VIEW FUNCTIONS                 //
	// ------------------------------------------ //

	// NOTE: Use 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE as token to get ETH fees
	function getProtocolFeesEarned(address _token) public view returns (uint256) {
		if (_token == ETH) {
			return address(this).balance - assetsHeldForVesting[ETH];
		} else {
			return IERC20(_token).balanceOf(address(this)) - assetsHeldForVesting[_token];
		}
	}

	// returns (total vested amount - withdrawn) - fees
	function getWithdrawableAmount(uint256 _vBoxId, address _account) public view returns (uint256) {
		VestingBoxAccount memory vBoxAcc = vBoxAccounts[_vBoxId][_account];

		if (block.timestamp >= vBoxAcc.endTime) {
			return vBoxAcc.amount - vBoxAcc.withdrawn;
		}

		uint256 vestedTime = block.timestamp - vBoxAcc.startTime;
		uint256 totalTime = vBoxAcc.endTime - vBoxAcc.startTime;
		uint256 vestedAmount = (vBoxAcc.amount * vestedTime * SCALE) / (totalTime * SCALE);

		return calcAfterFeeAmount(vestedAmount - vBoxAcc.withdrawn);
	}

	// Returns entire vested amount regardless of amount withdrawn or fees
	function getVestedAmount(uint256 _vBoxId, address _account) public view returns (uint256) {
		VestingBoxAccount memory vBoxAcc = vBoxAccounts[_vBoxId][_account];

		if (block.timestamp >= vBoxAcc.endTime) {
			return vBoxAcc.amount;
		}

		uint256 vestedTime = block.timestamp - vBoxAcc.startTime;
		uint256 totalTime = vBoxAcc.endTime - vBoxAcc.startTime;
		uint256 vestedAmount = (vBoxAcc.amount * vestedTime * SCALE) / (totalTime * SCALE);

		return vestedAmount;
	}

	// Takes amount before fee and returns amount after fee
	function calcAfterFeeAmount(uint256 _beforeFeeAmount) public view returns (uint256) {
		return (_beforeFeeAmount * (SCALE - fee)) / SCALE;
	}

	// Takes amount after fee and returns amount before fee
	function calcBeforeFeeAmount(uint256 _afterFeeAmount) public view returns (uint256) {
		return (_afterFeeAmount * SCALE) / (SCALE - fee);
	}

	// ------------------------------------------ //
	//                MODIFIERS                   //
	// ------------------------------------------ //

	modifier onlyVestingBoxAdmin(uint256 _vBoxId, address _account) {
		require(isAdminOfVBox[_vBoxId][_account], 'VEST: NOT VBOX ADMIN');
		_;
	}
}
