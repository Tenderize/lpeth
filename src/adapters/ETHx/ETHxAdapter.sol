pragma solidity >=0.8.20;

import { Adapter } from "@/adapters/Adapter.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { IUserWithdrawalManager, IStaderStakePoolsManager, UserWithdrawInfo } from "@/adapters/ETHx/IStader.sol";

address constant STADER_USER_WITHDRAWAL_MANAGER = 0x9F0491B32DBce587c50c4C43AB303b06478193A7;
address constant STADER_STAKE_POOLS_MANAGER = 0xcf5EA1b38380f6aF39068375516Daf40Ed70D299;
address constant ETHx_TOKEN = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;

uint256 constant MIN_AMOUNT = 100_000_000_000_000; // 0,0001 ETH
uint256 constant MAX_AMOUNT = 10_000 ether;

contract ETHxAdapter is Adapter {
    function previewWithdraw(uint256 amount) external view returns (uint256) {
        return IStaderStakePoolsManager(STADER_STAKE_POOLS_MANAGER).previewWithdraw(amount);
    }

    function requestWithdraw(uint256 amount) external returns (uint256 tokenId, uint256 amountExpected) {
        SafeTransferLib.safeApprove(ETHx_TOKEN, STADER_USER_WITHDRAWAL_MANAGER, amount);
        tokenId = IUserWithdrawalManager(STADER_USER_WITHDRAWAL_MANAGER).requestWithdraw(amount, address(this));
        amountExpected =
            IUserWithdrawalManager(STADER_USER_WITHDRAWAL_MANAGER).userWithdrawRequests(tokenId).ethExpected;
    }

    function claimWithdraw(uint256 tokenId) external returns (uint256 amount) {
        uint256 balBefore = address(this).balance;
        IUserWithdrawalManager(STADER_USER_WITHDRAWAL_MANAGER).claim(tokenId);
        amount = address(this).balance - balBefore;
    }

    function isFinalized(uint256 tokenId) external view returns (bool) {
        return tokenId < IUserWithdrawalManager(STADER_USER_WITHDRAWAL_MANAGER).nextRequestIdToFinalize();
    }

    function totalStaked() external view returns (uint256) {
        return IStaderStakePoolsManager(STADER_STAKE_POOLS_MANAGER).totalAssets();
    }

    function minMaxAmount() external pure returns (uint256 min, uint256 max) {
        return (MIN_AMOUNT, MAX_AMOUNT);
    }
}
