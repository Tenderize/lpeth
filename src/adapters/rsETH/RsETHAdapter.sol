pragma solidity >=0.8.25;

import { Adapter } from "@/adapters/Adapter.sol";
import {
    DEPOSIT_POOL,
    DepositPool,
    ETH_TOKEN,
    WITHDRAWALS,
    Withdrawals,
    _getRequestID,
    WithdrawalRequest
} from "@/adapters/rsETH/IKelp.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

address constant RSETH_TOKEN = 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7;
uint256 constant MIN_AMOUNT = 5_000_000_000_000_000; // 0.005 ETH
uint256 constant MAX_AMOUNT = 1000 ether;

contract RsETHAdapter is Adapter {
    struct WithdrawNonces {
        address asset;
        uint256 nonce;
    }

    mapping(bytes32 => WithdrawNonces) internal withdrawNonces;

    function previewWithdraw(uint256 amount) external view override returns (uint256 amountExpected) {
        return Withdrawals(WITHDRAWALS).getExpectedAssetAmount(ETH_TOKEN, amount);
    }

    function requestWithdraw(uint256 amount) external override returns (uint256 tokenId, uint256 amountExpected) {
        SafeTransferLib.safeApprove(RSETH_TOKEN, WITHDRAWALS, amount);
        Withdrawals w = Withdrawals(WITHDRAWALS);
        uint256 nonce = w.nextUnusedNonce(ETH_TOKEN);
        amountExpected = w.getExpectedAssetAmount(ETH_TOKEN, amount);
        tokenId = uint256(_getRequestID(ETH_TOKEN, nonce));
        withdrawNonces[bytes32(tokenId)] = WithdrawNonces(ETH_TOKEN, nonce);

        // This call will revert if the amount of available ETH is less than the amount requested
        w.initiateWithdrawal(ETH_TOKEN, amount, "");
    }

    function claimWithdraw(uint256 tokenId) external override returns (uint256 amount) {
        isFinalized(tokenId);
        Withdrawals w = Withdrawals(WITHDRAWALS);
        uint256 balBefore = address(this).balance;
        w.completeWithdrawal(ETH_TOKEN, "");
        amount = address(this).balance - balBefore;
    }

    function isFinalized(uint256 tokenId) public view override returns (bool) {
        uint256 nextLockedNonce = Withdrawals(WITHDRAWALS).nextLockedNonce(ETH_TOKEN);
        return withdrawNonces[bytes32(tokenId)].nonce >= nextLockedNonce;
    }

    function totalStaked() external view override returns (uint256) {
        return DepositPool(DEPOSIT_POOL).getTotalAssetDeposits(ETH_TOKEN);
    }

    function minMaxAmount() external pure override returns (uint256 min, uint256 max) {
        return (MIN_AMOUNT, MAX_AMOUNT);
    }
}
