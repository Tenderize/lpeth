pragma solidity >=0.8.25;

import { Adapter } from "@/adapters/Adapter.sol";
import { IswETH, IswEXIT } from "@/adapters/swETH/ISwell.sol";
import { wrap, unwrap } from "@prb/math/UD60x18.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

address constant RSWETH_TOKEN = 0xFAe103DC9cf190eD75350761e95403b7b8aFa6c0;
address constant RSWEXIT = 0x58749C46Ffe97e4d79508a2C781C440f4756f064;

uint256 constant MIN_AMOUNT = 5_000_000_000_000_000; // 0.005 ETH
uint256 constant MAX_AMOUNT = 500 ether;

contract RswETHAdapter is Adapter {
    function previewWithdraw(uint256 amount) external view returns (uint256) {
        return wrap(amount).mul(wrap(IswETH(RSWETH_TOKEN).getRate())).unwrap();
    }

    function requestWithdraw(uint256 amount) external returns (uint256 tokenId, uint256 amountExpected) {
        SafeTransferLib.safeApprove(RSWETH_TOKEN, RSWEXIT, amount);
        amountExpected = wrap(amount).mul(wrap(IswETH(RSWETH_TOKEN).getRate())).unwrap();
        IswEXIT(RSWEXIT).createWithdrawRequest(amount);
        tokenId = IswEXIT(RSWEXIT).getLastTokenIdCreated();
    }

    function claimWithdraw(uint256 tokenId) external returns (uint256 amount) {
        uint256 balBefore = address(this).balance;
        IswEXIT(RSWEXIT).finalizeWithdrawal(tokenId);
        amount = address(this).balance - balBefore;
    }

    function isFinalized(uint256 tokenId) external view returns (bool) {
        return IswEXIT(RSWEXIT).getLastTokenIdProcessed() >= tokenId;
    }

    function totalStaked() external view returns (uint256) {
        return wrap(IswETH(RSWETH_TOKEN).totalSupply()).mul(wrap(IswETH(RSWETH_TOKEN).getRate())).unwrap();
    }

    function minMaxAmount() external pure returns (uint256 min, uint256 max) {
        return (MIN_AMOUNT, MAX_AMOUNT);
    }
}
