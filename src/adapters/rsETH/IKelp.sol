pragma solidity ^0.8.25;

address constant ETH_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
address constant WITHDRAWALS = 0x62De59c08eB5dAE4b7E6F7a8cAd3006d6965ec16;
address constant DEPOSIT_POOL = 0x036676389e48133B63a802f8635AD39E752D375D;

struct WithdrawalRequest {
    uint256 rsETHUnstaked;
    uint256 expectedAssetAmount;
    uint256 withdrawalStartBlock;
}

interface Withdrawals {
    function nextUnusedNonce(address asset) external view returns (uint256);
    function nextLockedNonce(address asset) external view returns (uint256);
    function getExpectedAssetAmount(
        address asset,
        uint256 amount
    )
        external
        view
        returns (uint256 underlyingToReceive);
    function initiateWithdrawal(address asset, uint256 rsETHUnstaked) external;
    function completeWithdrawal(address asset) external;
    function getAvailableAssetAmount(address asset) external view returns (uint256 availableAssetAmount);
    function withdrawalRequests(bytes32 id) external view returns (WithdrawalRequest memory);
}

interface DepositPool {
    function getTotalAssetDeposits(address asset) external view returns (uint256 totalAssetDeposit);
}

function _getRequestID(address asset, uint256 nonce) pure returns (bytes32) {
    return keccak256(abi.encodePacked(asset, nonce));
}
