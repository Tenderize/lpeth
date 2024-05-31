pragma solidity >=0.8.20;

import { WithdrawQueue } from "@/lpETH/WithdrawQueue.sol";

import { Test, console } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";

contract WithdrawQueue_Harness {
    using WithdrawQueue for WithdrawQueue.Data;

    WithdrawQueue.Data queue;

    receive() external payable { }

    function createRequest(uint128 amount) public returns (uint256) {
        return queue.createRequest(amount, payable(msg.sender));
    }

    function claimRequest(uint256 id) public returns (uint256) {
        return queue.claimRequest(id);
    }

    function finalizeRequests(uint256 amount) public payable {
        queue.finalizeRequests(amount);
    }

    function getClaimableForRequest(uint256 id) public view returns (uint256) {
        return queue.getClaimableForRequest(id);
    }

    function length() public view returns (uint256) {
        return queue.length();
    }

    function amountUnfinalized() public view returns (uint256) {
        return queue.amountUnfinalized();
    }

    function getHead() public view returns (uint256) {
        return queue.head;
    }

    function getTail() public view returns (uint256) {
        return queue.tail;
    }

    function getLifetimeFinalized() public view returns (uint256) {
        return queue.lifetimeFinalized;
    }

    function getPartiallyFinalizedAmount() public view returns (uint128) {
        return queue.partiallyFinalizedAmount;
    }
}

contract WithdrawQueueTest is Test {
    receive() external payable { }

    WithdrawQueue_Harness harness;

    function setUp() public {
        harness = new WithdrawQueue_Harness();
    }

    function test_createRequest() public {
        uint256 id = harness.createRequest(1000);
        assertEq(harness.getHead(), 1);
        assertEq(harness.getTail(), 1);
        assertEq(id, 1);
        id = harness.createRequest(1000);
        assertEq(id, 2);
        assertEq(harness.getHead(), 1);
        assertEq(harness.getTail(), 2);
    }

    function test_finalizeRequests() public {
        harness.createRequest(1000);
        harness.createRequest(2000);
        harness.finalizeRequests{ value: 1500 }(1500);
        assertEq(harness.getHead(), 2);
        assertEq(harness.getTail(), 2);
        assertEq(harness.getLifetimeFinalized(), 1500);
        assertEq(harness.getPartiallyFinalizedAmount(), 500);
        harness.finalizeRequests{ value: 250 }(250);
        assertEq(harness.getHead(), 2);
        assertEq(harness.getTail(), 2);
        assertEq(harness.getLifetimeFinalized(), 1750);
        assertEq(harness.getPartiallyFinalizedAmount(), 750);
    }

    function test_claimRequest() public {
        uint256 id = harness.createRequest(1000);
        harness.finalizeRequests{ value: 1000 }(1000);
        assertEq(harness.claimRequest(id), 1000);
        assertEq(harness.getHead(), 1);
        assertEq(harness.getTail(), 1);
        assertEq(harness.getLifetimeFinalized(), 1000);
        assertEq(harness.getClaimableForRequest(id), 0);
    }

    function test_getClaimableForRequest() public {
        uint256 id = harness.createRequest(1000);
        harness.finalizeRequests{ value: 1000 }(1000);
        assertEq(harness.getClaimableForRequest(id), 1000);
    }

    function test_length() public {
        harness.createRequest(1000);
        harness.createRequest(2000);
        assertEq(harness.length(), 2);
    }

    function test_amountUnfinalized() public {
        harness.createRequest(1000);
        harness.createRequest(2000);
        harness.finalizeRequests(1500);
        assertEq(harness.amountUnfinalized(), 1500);
    }
}
