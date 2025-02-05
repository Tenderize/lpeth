pragma solidity >=0.8.25;

import { Adapter } from "@/adapters/Adapter.sol";
import { IswETH, IswEXIT } from "@/adapters/swETH/ISwell.sol";
import { wrap, unwrap } from "@prb/math/UD60x18.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

address constant SWETH_TOKEN = 0xf951E335afb289353dc249e82926178EaC7DEd78;
address constant SWEXIT = 0x48C11b86807627AF70a34662D4865cF854251663;

uint256 constant MIN_AMOUNT = 5_000_000_000_000_000; // 0.005 ETH
uint256 constant MAX_AMOUNT = 500 ether;

contract SwETHAdapter is Adapter {
    function previewWithdraw(uint256 amount) external view returns (uint256) {
        return wrap(amount).mul(wrap(IswETH(SWETH_TOKEN).getRate())).unwrap();
    }

    function requestWithdraw(uint256 amount) external returns (uint256 tokenId, uint256 amountExpected) {
        SafeTransferLib.safeApprove(SWETH_TOKEN, SWEXIT, amount);
        amountExpected = wrap(amount).mul(wrap(IswETH(SWETH_TOKEN).getRate())).unwrap();
        IswEXIT(SWEXIT).createWithdrawRequest(amount);
        tokenId = IswEXIT(SWEXIT).getLastTokenIdCreated();
    }

    function claimWithdraw(uint256 tokenId) external returns (uint256 amount) {
        uint256 balBefore = address(this).balance;
        IswEXIT(SWEXIT).finalizeWithdrawal(tokenId);
        amount = address(this).balance - balBefore;
    }

    function isFinalized(uint256 tokenId) external view returns (bool) {
        return IswEXIT(SWEXIT).getLastTokenIdProcessed() >= tokenId;
    }

    function totalStaked() external view returns (uint256) {
        return wrap(IswETH(SWETH_TOKEN).totalSupply()).mul(wrap(IswETH(SWETH_TOKEN).getRate())).unwrap();
    }

    function minMaxAmount() external pure returns (uint256 min, uint256 max) {
        return (MIN_AMOUNT, MAX_AMOUNT);
    }
}
