pragma solidity >=0.8.20;

address constant LPETH = address(0);

error NotFinalized(uint256 id);
error InsufficientMsgvalue();
error Unauthorized();

struct WithdrawRequest {
    uint128 amount; // original request amount
    uint128 claimed; // amount claimed
    uint256 cumulative; // cumulative lifetime requested
    address payable account;
}

contract WithdrawQueue {
    uint256 private head;
    uint256 private tail;
    uint256 private lifetimeFinalized;
    uint128 private partiallyFinalizedAmount;

    mapping(uint256 id => WithdrawRequest) private queue;

    receive() external payable { }

    function createRequest(uint128 amount, address payable account) external returns (uint256 id) {
        if (msg.sender != LPETH) revert Unauthorized();
        // start head at 1
        id = ++tail;
        queue[id] = WithdrawRequest(amount, 0, queue[id - 1].cumulative + amount, account);
        if (head == 0) head = 1;
    }

    function claimRequest(uint256 id) external {
        WithdrawRequest storage req = queue[id];
        if (msg.sender != req.account) revert Unauthorized();
        if (id < head) {
            uint256 amount = req.amount - req.claimed;
            delete queue[id];
            req.account.transfer(amount);
        } else if (id == head) {
            req.claimed = partiallyFinalizedAmount;
            req.account.transfer(partiallyFinalizedAmount);
        } else {
            revert NotFinalized(id);
        }
    }

    function finalizeRequests() external payable {
        uint256 amount = msg.value;
        if (msg.sender != LPETH) revert Unauthorized();
        uint256 index = _findFinalizableIndex(head, tail, amount);
        head = index + 1;
        partiallyFinalizedAmount = uint128(amount - (queue[index].cumulative - lifetimeFinalized));
        lifetimeFinalized += amount;
    }

    function getClaimableForRequest(uint256 id) external view returns (uint256) {
        if (id < head) {
            WithdrawRequest memory req = queue[id];
            return req.amount - req.claimed;
        } else if (id == head) {
            WithdrawRequest memory req = queue[id];
            return partiallyFinalizedAmount - req.claimed;
        } else {
            return 0;
        }
    }

    function length() external view returns (uint256) {
        return tail - head;
    }

    function amountUnfinalized() external view returns (uint256) {
        return queue[tail].cumulative - lifetimeFinalized;
    }

    function _findFinalizableIndex(uint256 start, uint256 end, uint256 amount) internal view returns (uint256) {
        uint256 _ltf = lifetimeFinalized;

        while (start < end) {
            uint256 mid = (start + end) / 2;
            uint256 midCumulative = queue[mid].cumulative;

            if (midCumulative - _ltf == amount) {
                return mid;
            } else if (midCumulative - _ltf <= amount) {
                start = mid + 1;
            } else {
                end = mid;
            }
        }

        return start;
    }
}
