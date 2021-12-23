// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import './interfaces/IVestERC20Factory.sol';
import './VestERC20.sol';

import 'hardhat/console.sol';

// ------------------------------------------- //
//             🦺 VestCore v0.1 🦺             //
// ------------------------------------------ //

// TODO Natspec all functions
// TODO make sure all vars are used efficiently (mappings vs arrays)
// TODO check if all return types are needed
// TODO events for everything important

/**
    @title VestCore
 */
contract VestCore is Ownable {
	uint256 public constant SCALE = 1e18;
	uint256 public fee = 1e15; // 0.1% fee
	uint256 public vBoxCount = 0;

	IVestERC20Factory public tokenFactory;
	address public ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

	// Stores all properties of a vesting agreement
	// vBox for short in var naming
	struct VestingBox {
		address token;
		address[] admins; // is this needed in struct? can we just use mapping? needed to pass in data as arg only???
		address[] recipients; // same here, do we need to store the array?
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

	event VestingBoxCreated(uint256 indexed vBoxID, address indexed token, address creator, uint256 totalBoxAmount);
	event VestedTokensClaimed(uint256 indexed vBoxID, address indexed token, uint256 amountClaimed, address recipient);

	event VestingBoxAdminSet(uint256 indexed vBoxID, address account, bool isAdmin);

	event AccountAddedToVestingBox(
		uint256 indexed vBoxID,
		address account,
		uint256 amount,
		uint128 startTime,
		uint128 endTime
	);
	event AccountRemovedFromVestingBox(
		uint256 indexed vBoxID,
		address account,
		uint256 amountVested,
		uint256 amountForfeited
	);

	event FeesWithdrawn(address token, uint256 amount, address _to);
	event FeesSet(uint256 oldFee, uint256 newFee);

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
		VestingBoxAccount[] memory _vBoxAccounts
	) external returns (bool) {
		return _createVestingBox(_totalAmount, _vBox, _vBoxAccounts, false);
	}

	// NOTE: _vBox token left blank, will be set to newly created token
	function createVestingBoxWithNewToken(
		uint256 _totalAmount,
		VestingBox memory _vBox,
		VestingBoxAccount[] memory _vBoxAccounts,
		string calldata _tokenName,
		string calldata _tokenSymbol,
		uint256 _tokenTotalSupply
	) external returns (bool) {
		// creates new token and sets address in _vBox before creating vBox
		_vBox.token = _createERC20(_tokenName, _tokenSymbol, _tokenTotalSupply);
		return _createVestingBox(_totalAmount, _vBox, _vBoxAccounts, true);
	}

	function createVestingBoxWithETH(
		uint256 _totalAmount,
		VestingBox memory _vBox,
		VestingBoxAccount[] memory _vBoxAccounts
	) external payable returns (bool) {
		_vBox.token = ETH;
		return _createVestingBox(_totalAmount, _vBox, _vBoxAccounts, false);
	}

	// check manual setting amounta and withdrawn don't cause claim exploits
	function claimVestedTokens(uint256 _vBoxId, uint256 _amountToClaim) public returns (bool) {
		// withdrawableAmount = total vested - withdrawn
		uint256 withdrawableAmount = getWithdrawableAmount(_vBoxId, msg.sender);
		require(withdrawableAmount >= _amountToClaim, 'VEST: NOT ENOUGH VESTED');

		// Send tokens to recipient
		_withdrawFromVBox(_vBoxId, _amountToClaim);

		emit VestedTokensClaimed(_vBoxId, vBoxes[_vBoxId].token, _amountToClaim, msg.sender);

		return true;
	}

	// TODO if error in start/end times, all tokens withdrawable

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

	function setTokenFactory(IVestERC20Factory _newFactory) external onlyOwner {
		require(address(_newFactory) != address(0), 'VEST: FACTORY NOT ZERO ADDRESS');
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
	function removeAccountFromVestingBox(uint256 _vBoxId, address _recipient)
		external
		onlyVestingBoxAdmin(_vBoxId, msg.sender)
	{
		// TODO
		// event AccountRemovedFromVestingBox(
		// 	uint256 indexed vBoxID,
		// 	address account,
		// 	uint256 amountVested,
		// 	uint256 amountForfeited
		// );
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
		bool _newToken
	) internal returns (bool) {
		require(_totalAmount > 0, 'VEST: CANNOT VEST 0 AMOUNT');
		require(_vBox.recipients.length > 0, 'VEST: NO RECIPIENTS');
		require(_vBox.recipients.length == _vBoxAccounts.length, 'VEST: WRONG ACCOUNTS ARRAY LEN');

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

		for (uint256 i = 0; i < _vBoxAccounts.length; i++) {
			_checkVBoxAccountValid(_vBoxAccounts[i]);
			vBoxAccounts[vBoxCount][_vBox.recipients[i]] = _vBoxAccounts[i];
		}

		assetsHeldForVesting[_vBox.token] += _totalAmount;

		emit VestingBoxCreated(vBoxCount, _vBox.token, msg.sender, _totalAmount);

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

	function _checkVBoxAccountValid(VestingBoxAccount memory _vBoxAccount) internal {
		require(_vBoxAccount.startTime < _vBoxAccount.endTime, 'VEST: START TIME AFTER END TIME');
		require(_vBoxAccount.endTime > block.timestamp, 'VEST: END TIME IN THE PAST');
		require(_vBoxAccount.amount > 0, 'VEST: CANNOT VEST 0 AMOUNT');
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

	// NOTE: Use 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE as token to get ETH held
	function getAssetHeldForVesting(address _token) public view returns (uint256) {
		return assetsHeldForVesting[_token];
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

	modifier onlyVestingBoxAdmin(uint256 _vBoxId, address _account) {
		require(isAdminOfVBox[_vBoxId][_account], 'VEST: NOT VBOX ADMIN');
		_;
	}

	modifier hasAmountInBox(uint256 _vBoxId, address _account) {
		require(vBoxAccounts[_vBoxId][_account].amount > 0, 'VEST: NO AMOUNT IN BOX');
		_;
	}
}
