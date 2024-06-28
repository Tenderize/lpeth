// SPDX-License-Identifier: MIT
//
//  _____              _           _
// |_   _|            | |         (_)
//   | | ___ _ __   __| | ___ _ __ _ _______
//   | |/ _ \ '_ \ / _` |/ _ \ '__| |_  / _ \
//   | |  __/ | | | (_| |  __/ |  | |/ /  __/
//   \_/\___|_| |_|\__,_|\___|_|  |_/___\___|
//
// Copyright (c) Tenderize Labs Ltd

pragma solidity >=0.8.20;

import { SafeTransferLib } from "@solady/utils/SafeTransferLib.sol";

library WithdrawQueue {
    error NotFinalized(uint256 id);
    error Unauthorized();
    error NoClaimableETH();

    struct Request {
        uint256 amount; // original request amount
        uint256 cumulative; // cumulative requested *before* this request in the current round
        uint256 round; // round this request was created in
        address payable account;
    }

    struct Data {
        uint256 lastId;
        uint256 currentRound;
        uint256 totalFinalized;
        mapping(uint256 id => Request) queue;
    }

    function createRequest(Data storage $, uint128 amount, address payable account) external returns (uint256 id) {
        // Check if lastId has been finalized
        Request memory prev = $.queue[$.lastId];
        id = ++$.lastId; // start head at 1

        // Check if last known ID has been finalized
        // if `prev.round` <= `$.currentRound` -> true
        // the current 'queue' is empty and we can start cumulative from 0
        // as the last call of `finalizeRequest` has also set `totalFinalized` back to 0
        // otherwise proceed as normal and set cumulative to `prev.cumulative + prev.amount`

        uint256 cumulative = prev.cumulative + prev.amount;
        if (prev.round < $.currentRound) cumulative = 0;

        $.queue[id] = Request({
            amount: amount,
            // checkpoint cumulative requested
            cumulative: cumulative,
            account: account,
            round: $.currentRound
        });
    }

    function claimRequest(Data storage $, uint256 id) external returns (uint256 amount) {
        Request storage req = $.queue[id];
        if (msg.sender != req.account) revert Unauthorized();

        if (req.round < $.currentRound || req.cumulative + req.amount <= $.totalFinalized) {
            // Fully finalized, full amount is claimable
            // We can remove the entry
            amount = req.amount;
            delete $.queue[id];
        } else {
            // Partially finalized, calculate claimable amount
            // And update state
            amount = $.totalFinalized - req.cumulative;
            req.amount -= amount;
            req.cumulative += amount;
        }

        if (amount == 0) revert NoClaimableETH();
        SafeTransferLib.safeTransferETH(req.account, amount);
    }

    function finalizeRequests(Data storage $, uint256 amount) external {
        uint256 lastId = $.lastId;
        if (lastId == 0) return;

        Request memory req = $.queue[lastId];

        uint256 max = req.cumulative + req.amount - $.totalFinalized;
        // If `amount > max` we can finalize all pending requests.
        // In this case we can increment `currentRound` and reset `totalFinalized` to 0.
        // The next request created will start its `cumulative` from 0.
        if (amount >= max) {
            amount = max;
            $.currentRound++;
            $.totalFinalized = 0;
        } else {
            $.totalFinalized += amount;
        }
    }

    function getClaimableForRequest(Data storage $, uint256 id) external view returns (uint256 amount) {
        Request storage req = $.queue[id];

        if (req.round < $.currentRound || req.cumulative + req.amount <= $.totalFinalized) {
            // Fully finalized, full amount is claimable
            // We can remove the entry
            amount = req.amount;
        } else {
            // Partially finalized, calculate claimable amount
            // And update state
            amount = $.totalFinalized - req.cumulative;
        }
    }

    function getRequest(Data storage $, uint256 id) external view returns (Request memory) {
        return $.queue[id];
    }
}
