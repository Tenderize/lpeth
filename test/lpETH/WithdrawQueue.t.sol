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

    function getLastId() public view returns (uint256) {
        return queue.lastId;
    }

    function getTotalFinalized() public view returns (uint256) {
        return queue.totalFinalized;
    }

    function getRequest(uint256 id) public view returns (WithdrawQueue.Request memory) {
        return queue.queue[id];
    }
}

contract WithdrawQueueTest is Test {
    WithdrawQueue_Harness harness;
    address payable user1;
    address payable user2;

    function setUp() public {
        harness = new WithdrawQueue_Harness();
        user1 = payable(address(0x1));
        user2 = payable(address(0x2));
    }

    function testCreateRequest() public {
        uint256 amount = 100 ether;

        vm.prank(user1);
        uint256 id = harness.createRequest(uint128(amount));

        uint256 lastId = harness.getLastId();
        assertEq(lastId, id, "Last ID should match the created request ID");

        WithdrawQueue.Request memory req = harness.getRequest(id);

        assertEq(req.amount, amount, "Amount should match the requested amount");
        assertEq(req.account, user1, "Account should match the requester");
        assertEq(req.cumulative, 0, "Cumulative should be 0 for the first request");
        assertEq(req.round, 0, "Round should be 0 for the first request");
    }

    function test_claimRequest_NotFinalized() public {
        uint256 amount = 100 ether;

        vm.prank(user1);
        uint256 id = harness.createRequest(uint128(amount));

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(WithdrawQueue.NoClaimableETH.selector));
        harness.claimRequest(id);
    }

    function test_claimRequest_Unauthorized() public {
        uint256 amount = 100 ether;

        vm.prank(user1);
        uint256 id = harness.createRequest(uint128(amount));

        vm.deal(address(harness), amount);
        harness.finalizeRequests(amount);

        vm.prank(user2);
        vm.expectRevert(WithdrawQueue.Unauthorized.selector);
        harness.claimRequest(id);
    }

    function test_claimRequest_NoClaimableETH() public {
        uint256 amount = 100 ether;

        vm.prank(user1);
        uint256 id = harness.createRequest(uint128(amount));

        vm.prank(user1);
        vm.expectRevert(WithdrawQueue.NoClaimableETH.selector);
        harness.claimRequest(id);
    }

    function test_claimRequest_partially_available() public {
        uint256 amount = 100 ether;

        vm.prank(user1);
        uint256 id = harness.createRequest(uint128(amount));

        vm.deal(address(harness), 50 ether);
        harness.finalizeRequests(50 ether);

        uint256 claimable = harness.getClaimableForRequest(id);
        assertEq(claimable, 50 ether, "Claimable amount should be 50 ether");

        vm.prank(user1);
        uint256 claimedAmount = harness.claimRequest(id);
        assertEq(claimedAmount, 50 ether, "Claimed amount should be 50 ether");

        WithdrawQueue.Request memory req = harness.getRequest(id);
        assertEq(req.cumulative, 50 ether, "Cumulative should be updated to 50 ether");
        assertEq(req.amount, 50 ether, "Amount should be updated to 50 ether");
    }

    function test_claimRequest_full() public {
        uint256 amount = 100 ether;

        vm.prank(user1);
        uint256 id = harness.createRequest(uint128(amount));

        vm.deal(address(harness), amount);
        harness.finalizeRequests(amount);

        uint256 claimable = harness.getClaimableForRequest(id);
        assertEq(claimable, amount, "Claimable amount should be 100 ether");

        vm.prank(user1);
        uint256 claimedAmount = harness.claimRequest(id);
        assertEq(claimedAmount, amount, "Claimed amount should be 100 ether");

        WithdrawQueue.Request memory req = harness.getRequest(id);
        assertEq(req.cumulative, 0, "Cumulative should be reset to 0 after full claim");
    }

    function test_finalizeRequests() public {
        uint256 amount1 = 100 ether;
        uint256 amount2 = 200 ether;

        vm.prank(user1);
        harness.createRequest(uint128(amount1));
        vm.prank(user2);
        uint256 id2 = harness.createRequest(uint128(amount2));

        vm.deal(address(harness), 150 ether);
        harness.finalizeRequests(150 ether);

        uint256 claimable1 = harness.getClaimableForRequest(1);
        uint256 claimable2 = harness.getClaimableForRequest(id2);

        assertEq(claimable1, 100 ether, "User1 should be able to claim full amount");
        assertEq(claimable2, 50 ether, "User2 should be able to claim partial amount");

        vm.prank(user1);
        harness.claimRequest(1);

        vm.prank(user2);
        harness.claimRequest(id2);

        WithdrawQueue.Request memory req = harness.getRequest(id2);
        assertEq(req.cumulative, 150 ether, "User2's cumulative should be updated to 150 ether");

        vm.deal(address(harness), 150 ether);
        harness.finalizeRequests(150 ether);

        claimable2 = harness.getClaimableForRequest(id2);
        assertEq(claimable2, 150 ether, "User2 should be able to claim remaining 150 ether");

        vm.prank(user2);
        harness.claimRequest(id2);

        req = harness.getRequest(id2);
        assertEq(req.cumulative, 0, "User2's cumulative should be reset to 0 after full claim");
    }
}
