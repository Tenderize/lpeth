pragma solidity >=0.8.20;

import { Adapter } from "@/adapters/Adapter.sol";
import { IStaking } from "@/adapters/mETH/IMantle.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";

address constant STAKING = 0xe3cBd06D7dadB3F4e6557bAb7EdD924CD1489E8f;
address constant METH_TOKEN = 0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa;

uint256 constant MIN_AMOUNT = 10_000_000_000_000_000; // 0.01 ETH
uint256 constant MAX_AMOUNT = type(uint128).max;

contract METHAdapter is Adapter {
    function previewWithdraw(uint256 amount) external view returns (uint256) {
        return IStaking(STAKING).mETHToETH(amount);
    }

    function requestWithdraw(uint256 amount) external returns (uint256 tokenId, uint256 amountExpected) {
        SafeTransferLib.safeApprove(METH_TOKEN, STAKING, amount);

        // Safe cast amount to uint128
        // calculate minEthReceived
        uint128 safeCastAmount = SafeCastLib.toUint128(amount);
        amountExpected = IStaking(STAKING).mETHToETH(amount);
        // no need to safeCast amount expected
        tokenId = IStaking(STAKING).unstakeRequest(safeCastAmount, uint128(amountExpected));
    }

    function claimWithdraw(uint256 tokenId) external returns (uint256 amount) {
        uint256 balBefore = address(this).balance;
        IStaking(STAKING).claimUnstakeRequest(tokenId);
        amount = address(this).balance - balBefore;
    }

    function isFinalized(uint256 tokenId) external view returns (bool) {
        (bool finalized,) = IStaking(STAKING).unstakeRequestInfo(tokenId);
        return finalized;
    }

    function totalStaked() external view returns (uint256) {
        return IStaking(STAKING).totalControlled();
    }

    function minMaxAmount() external pure returns (uint256 min, uint256 max) {
        return (MIN_AMOUNT, MAX_AMOUNT);
    }
}
