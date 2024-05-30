pragma solidity >=0.8.20;

import { Adapter } from "@/adapters/Adapter.sol";
import { IRiver, IRedeemManager } from "@/adapters/lsETH/ILiquidCollective.sol";

import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

address constant REDEEM_MANAGER = 0x080b3a41390b357Ad7e8097644d1DEDf57AD3375;
address constant LSETH_TOKEN = 0x8c1BEd5b9a0928467c9B1341Da1D7BD5e10b6549;

contract LsETHAdapter is Adapter {
    function previewWithdraw(uint256 amount) external view returns (uint256) {
        return IRiver(LSETH_TOKEN).underlyingBalanceFromShares(amount);
    }

    function requestWithdraw(uint256 amount) external returns (uint256 tokenId, uint256 amountExpected) {
        SafeTransferLib.safeApprove(LSETH_TOKEN, LSETH_TOKEN, amount);
        amountExpected = IRiver(LSETH_TOKEN).underlyingBalanceFromShares(amount);
        tokenId = IRiver(LSETH_TOKEN).requestRedeem(amount, address(this));
    }

    function claimWithdraw(uint256 tokenId) external returns (uint256 amount) {
        uint256 balBefore = address(this).balance;
        uint32[] memory redeemRequestIds = new uint32[](1);
        redeemRequestIds[0] = uint32(tokenId);
        uint32[] memory withdrawalEventIds = new uint32[](1);
        // TODO: Safecast ?
        withdrawalEventIds[0] = uint32(int32(IRedeemManager(REDEEM_MANAGER).resolveRedeemRequests(redeemRequestIds)[0]));
        IRedeemManager(REDEEM_MANAGER).claimRedeemRequests(redeemRequestIds, withdrawalEventIds);
        amount = address(this).balance - balBefore;
    }

    function isFinalized(uint256 tokenId) external view returns (bool) {
        uint32[] memory redeemRequestIds = new uint32[](1);
        redeemRequestIds[0] = uint32(tokenId);
        int64[] memory withdrawalEventIds = IRedeemManager(REDEEM_MANAGER).resolveRedeemRequests(redeemRequestIds);
        return withdrawalEventIds[0] >= 0;
    }

    function totalStaked() external view returns (uint256) {
        return IRiver(LSETH_TOKEN).totalUnderlyingSupply();
    }

    function minMaxAmount() external view returns (uint256 min, uint256 max) {
        return (1e9, type(uint256).max);
    }
}
