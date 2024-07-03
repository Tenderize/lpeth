pragma solidity >=0.8.25;

// struct RedeemRequest {
//     /// @custom:attribute The amount of the redeem request in LsETH
//     uint256 amount;
//     /// @custom:attribute The maximum amount of ETH redeemable by this request
//     uint256 maxRedeemableEth; // equivalent to 'amountExpected' in
//     /// @custom:attribute The owner of the redeem request
//     address owner;
//     /// @custom:attribute The height is the cumulative sum of all the sizes of preceding redeem requests
//     uint256 height;
// }

// interface IRiver {
//     function totalUnderlyingSupply() external view returns (uint256);
//     function underlyingBalanceFromShares(uint256 _shares) external view returns (uint256);
//     function requestRedeem(uint256 _lsETHAmount, address _recipient) external returns (uint32 redeemRequestId);
// }

// interface IRedeemManager {
//     function getRedeemRequestDetails(uint32 _redeemRequestId) external view returns (RedeemRequest memory);

//     function resolveRedeemRequests(uint32[] calldata _redeemRequestIds)
//         external
//         view
//         returns (int64[] memory withdrawalEventIds);

//     function requestRedeem(uint256 _lsETHAmount) external returns (uint32 redeemRequestId);

//     function claimRedeemRequests(
//         uint32[] calldata _redeemRequestIds,
//         uint32[] calldata _withdrawalEventIds
//     )
//         external
//         returns (uint8[] memory claimStatuses);
// }
