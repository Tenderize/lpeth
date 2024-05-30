pragma solidity >=0.8.20;

import { Adapter } from "@/adapters/Adapter.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { ILiquidityPool, IWithdrawRequestNFT } from "@/adapters/eETH/IEtherfi.sol";

address constant ETHERFI_WITHDRAW_REQUEST_NFT = 0x7d5706f6ef3F89B3951E23e557CDFBC3239D4E2c;
address constant ETHERFI_LIQUIDITY_POOL = 0x308861A430be4cce5502d0A12724771Fc6DaF216;
address constant EETH_TOKEN = 0x35fA164735182de50811E8e2E824cFb9B6118ac2;

uint256 constant MIN_AMOUNT = 1e9;
uint256 constant MAX_AMOUNT = type(uint96).max;

contract EETHAdapter is Adapter {
    function previewWithdraw(uint256 amount) external view returns (uint256) {
        return ILiquidityPool(ETHERFI_LIQUIDITY_POOL).amountForShare(
            ILiquidityPool(ETHERFI_LIQUIDITY_POOL).sharesForAmount(amount)
        );
    }

    function requestWithdraw(uint256 amount) external returns (uint256 tokenId, uint256 amountExpected) {
        SafeTransferLib.safeApprove(EETH_TOKEN, ETHERFI_LIQUIDITY_POOL, amount);
        amountExpected = ILiquidityPool(ETHERFI_LIQUIDITY_POOL).amountForShare(
            ILiquidityPool(ETHERFI_LIQUIDITY_POOL).sharesForAmount(amount)
        );
        tokenId = ILiquidityPool(ETHERFI_LIQUIDITY_POOL).requestWithdraw(address(this), amount);
    }

    function claimWithdraw(uint256 tokenId) external returns (uint256 amount) {
        uint256 balBefore = address(this).balance;
        IWithdrawRequestNFT(ETHERFI_WITHDRAW_REQUEST_NFT).claimWithdraw(tokenId);
        amount = address(this).balance - balBefore;
    }

    function isFinalized(uint256 tokenId) external view returns (bool) {
        return IWithdrawRequestNFT(ETHERFI_WITHDRAW_REQUEST_NFT).isFinalized(tokenId);
    }

    function totalStaked() external view returns (uint256) {
        return ILiquidityPool(ETHERFI_LIQUIDITY_POOL).getTotalPooledEther();
    }

    function minMaxAmount() external pure returns (uint256 min, uint256 max) {
        return (MIN_AMOUNT, MAX_AMOUNT);
    }
}
