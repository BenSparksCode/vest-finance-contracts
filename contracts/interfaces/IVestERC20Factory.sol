interface IVestERC20Factory {
	function createERC20(
		string calldata _tokenName,
		string calldata _tokenSymbol,
		uint256 _tokenTotalSupply
	) external returns (address);

	function setCoreAddress(address _core) external;
}
