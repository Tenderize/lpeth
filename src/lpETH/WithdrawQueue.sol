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

// TODO: safeTransferETH

library WithdrawQueue {
    error NotFinalized(uint256 id);
    error InsufficientMsgvalue();
    error Unauthorized();
    error NoClaimableETH();

    struct Request {
        uint128 amount; // original request amount
        uint128 claimed; // amount claimed
        uint256 cumulative; // cumulative lifetime requested
        address payable account;
    }

    struct Data {
        uint256 head;
        uint256 tail;
        uint256 lifetimeFinalized;
        uint128 partiallyFinalizedAmount;
        mapping(uint256 id => Request) queue;
    }

    function createRequest(Data storage $, uint128 amount, address payable account) external returns (uint256 id) {
        // start head at 1
        id = ++$.tail;
        $.queue[id] = Request(amount, 0, $.queue[id - 1].cumulative + amount, account);
        if ($.head == 0) $.head = 1;
    }

    function claimRequest(Data storage $, uint256 id) external returns (uint256 amount) {
        Request storage req = $.queue[id];
        if (msg.sender != req.account) revert Unauthorized();
        if (id < $.head) {
            amount = req.amount - req.claimed;
            delete $.queue[id];
        } else if (id == $.head) {
            amount = $.partiallyFinalizedAmount - req.claimed;
            req.claimed = uint128(amount); // TODO: safecast
        } else {
            revert NotFinalized(id);
        }

        if (amount == 0) revert NoClaimableETH();
        req.account.transfer(amount);
    }

    function finalizeRequests(Data storage $, uint256 amount) external {
        uint256 index = _findFinalizableIndex($, $.head, $.tail, amount);
        if (index > 0) {
            $.head = index + 1;
            $.partiallyFinalizedAmount = uint128(amount - ($.queue[index].cumulative - $.lifetimeFinalized));
        } else {
            $.partiallyFinalizedAmount += uint128(amount);
        }

        $.lifetimeFinalized += amount;
    }

    function getClaimableForRequest(Data storage $, uint256 id) external view returns (uint256) {
        if (id < $.head) {
            Request memory req = $.queue[id];
            return req.amount - req.claimed;
        } else if (id == $.head) {
            Request memory req = $.queue[id];
            return $.partiallyFinalizedAmount - req.claimed;
        } else {
            return 0;
        }
    }

    function getRequest(Data storage $, uint256 id) external view returns (Request memory) {
        return $.queue[id];
    }

    function length(Data storage $) external view returns (uint256) {
        return $.tail - $.head + 1;
    }

    function amountUnfinalized(Data storage $) external view returns (uint256) {
        return $.queue[$.tail].cumulative - $.lifetimeFinalized;
    }

    function _findFinalizableIndex(
        Data storage $,
        uint256 start,
        uint256 end,
        uint256 amount
    )
        internal
        view
        returns (uint256)
    {
        uint256 _ltf = $.lifetimeFinalized;
        uint256 originalStart = start;

        while (start < end) {
            uint256 mid = (start + end) / 2;
            uint256 midCumulative = $.queue[mid].cumulative;

            if (midCumulative - _ltf == amount) {
                return mid;
            } else if (midCumulative - _ltf <= amount) {
                start = mid + 1;
            } else {
                end = mid;
            }
        }

        return start != originalStart ? start - 1 : 0;
    }
}
