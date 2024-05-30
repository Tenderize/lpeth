interface ILiquidityPool {
    function requestWithdraw(address recipient, uint256 amount) external returns (uint256 requestId);
    function amountForShare(uint256 share) external view returns (uint256);
    function sharesForAmount(uint256 amount) external view returns (uint256);
    function getTotalPooledEther() external view returns (uint256);
}

interface IWithdrawRequestNFT {
    function claimWithdraw(uint256 tokenId) external;
    function isFinalized(uint256 requestId) external view returns (bool);
    function getClaimableAmount(uint256 tokenId) external view returns (uint256);
}
