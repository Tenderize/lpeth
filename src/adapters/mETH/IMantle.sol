pragma solidity >=0.8.25;

// 0xe3cBd06D7dadB3F4e6557bAb7EdD924CD1489E8f

interface IStaking {
    function unstakeRequest(uint128 methAmount, uint128 minETHAmount) external returns (uint256 id);
    function claimUnstakeRequest(uint256 unstakeRequestID) external;
    function unstakeRequestInfo(uint256 unstakeRequestID)
        external
        view
        returns (bool finalized, uint256 claimableAmount);
    function mETHToETH(uint256 mETHAmount) external view returns (uint256);
    function totalControlled() external view returns (uint256);
}
