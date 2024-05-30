pragma solidity >=0.8.20;

import { Adapter } from "@/Registry.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { IStETH, IWithdrawalQueue, WithdrawalRequestStatus } from "@/adapters/stETH/ILido.sol";

address constant STETH_TOKEN = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
address constant LIDO_WITHDRAWAL_QUEUE = 0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1;
uint256 constant MIN_AMOUNT = 1e9;
uint256 constant MAX_AMOUNT = 1000 ether;

contract StETHAdapter is Adapter {
    function previewWithdraw(uint256 amount) external view returns (uint256) {
        return amount;
    }

    function requestWithdraw(uint256 amount) external returns (uint256 tokenId, uint256 amountExpected) {
        // This has a min and a max, so if below min (check) we have to batch
        // if above max we have to split into multiple requests
        // min is negligible, max is 1000 ETH this would result in multiple token Ids

        // We can solve this with a new abstraction in the adapter instead
        // We can have a function that returns the min and max amount
        // if the swap amount exceeds the max amount then we have to multicall it
        SafeTransferLib.safeApprove(STETH_TOKEN, LIDO_WITHDRAWAL_QUEUE, amount);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        tokenId = IWithdrawalQueue(LIDO_WITHDRAWAL_QUEUE).requestWithdrawals(amounts, address(this))[0];
        // TODO: find amount expected ?
        amountExpected = amount;
    }

    function claimWithdraw(uint256 tokenId) external returns (uint256 amount) {
        uint256 balBefore = address(this).balance;
        IWithdrawalQueue(LIDO_WITHDRAWAL_QUEUE).claimWithdrawal(tokenId);
        amount = address(this).balance - balBefore;
    }

    function isFinalized(uint256 tokenId) external view returns (bool) {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        return IWithdrawalQueue(LIDO_WITHDRAWAL_QUEUE).getWithdrawalStatus(tokenIds)[0].isFinalized;
    }

    function totalStaked() external view returns (uint256) {
        return IStETH(STETH_TOKEN).getTotalPooledEther();
    }

    function minMaxAmount() external pure returns (uint256 min, uint256 max) {
        return (MIN_AMOUNT, MAX_AMOUNT);
    }
}
