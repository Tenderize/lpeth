pragma solidity >=0.8.25;

/// @notice structure representing a user request for withdrawal.
struct UserWithdrawInfo {
    address payable owner; // address that can claim eth on behalf of this request
    uint256 ethXAmount; //amount of ethX share locked for withdrawal
    uint256 ethExpected; //eth requested according to given share and exchangeRate
    uint256 ethFinalized; // final eth for claiming according to finalize exchange rate
    uint256 requestBlock; // block number of withdraw request
}

interface IUserWithdrawalManager {
    // returns the request id
    function requestWithdraw(uint256 _ethXAmount, address _owner) external returns (uint256);
    function claim(uint256 _requestId) external;
    function userWithdrawRequests(uint256 _requestId) external view returns (UserWithdrawInfo memory);
    function nextRequestIdToFinalize() external view returns (uint256);
}

interface IStaderStakePoolsManager {
    function totalAssets() external view returns (uint256);
    function previewWithdraw(uint256 _ethXAmount) external view returns (uint256);
}
