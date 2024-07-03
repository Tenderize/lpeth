pragma solidity >=0.8.25;

import { Test, console } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";

import { LpETH, LpETHEvents, ConstructorConfig } from "@/lpETH/LpETH.sol";
import { WithdrawQueue } from "@/lpETH/WithdrawQueue.sol";
import { LPToken } from "@/lpETH/LPToken.sol";

import { Registry } from "@/Registry.sol";
import { Adapter } from "@/adapters/Adapter.sol";
import { UnsETH } from "@/unsETH/UnsETH.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { MockERC20 } from "../helpers/MockERC20.sol";
import { ERC721Receiver } from "@/utils/ERC721Receiver.sol";

// This is an integration test.
// Only `Adapter` calls are mocked.

// NOTE: Since this contract uses transient storage, use the "--isolate" flag to run the tests.
// This will execute top level calls as a context independent transaction.
// see: https://github.com/foundry-rs/foundry/issues/6908#issuecomment-2205157619

contract LpETH_Harness is LpETH {
    constructor(ConstructorConfig memory config) LpETH(config) { }
}

contract LPETH_Test is Test, ERC721Receiver {
    Registry registry;
    LPToken lpToken;
    LpETH_Harness lpETH;
    UnsETH unsETH;
    MockERC20 token1;
    MockERC20 token2;
    Adapter token1_adapter = Adapter(vm.addr(9876));
    Adapter token2_adapter = Adapter(vm.addr(9877));

    receive() external payable { }

    function setUp() public {
        token1 = new MockERC20("Token1", "T1");
        token2 = new MockERC20("Token 2", "T2");
        address registry_impl = address(new Registry());
        registry = Registry(address(new ERC1967Proxy(address(registry_impl), "")));
        registry.initialize();
        lpToken = new LPToken();
        address renderer = vm.addr(9878);
        address unsETH_impl = address(new UnsETH(address(registry), renderer));
        unsETH = UnsETH(payable(address(new ERC1967Proxy(unsETH_impl, ""))));
        unsETH.initialize();
        ConstructorConfig memory config =
            ConstructorConfig({ registry: registry, lpToken: lpToken, unsETH: unsETH, treasury: address(10) });
        address lpETH_impl = address(new LpETH_Harness(config));
        lpETH = LpETH_Harness(payable(address(new ERC1967Proxy(lpETH_impl, ""))));
        lpToken.transferOwnership(address(lpETH));
        registry.setAdapter(address(token1), token1_adapter);
        registry.setAdapter(address(token2), token2_adapter);
    }

    function test_deposit() public {
        vm.deal(payable(address(this)), 1000 ether);
        lpETH.deposit{ value: 1000 ether }(0);
        assertEq(lpToken.balanceOf(address(this)), 1000 ether);
        assertEq(lpToken.totalSupply(), 1000 ether);
        assertEq(lpETH.liabilities(), 1000 ether);

        // TODO: event
    }

    function test_deposit_errorSlippage() public {
        vm.deal(payable(address(this)), 1000 ether);
        vm.expectRevert(abi.encodeWithSelector(LpETHEvents.ErrorSlippage.selector, 1000 ether, 2000 ether));
        lpETH.deposit{ value: 1000 ether }(2000 ether);
    }

    function test_withdraw() public {
        // ===== SETUP =====
        // 1. deposit funds
        // 2. make a swap
        // 3. make a withdrawal in full, which
        // will be partially available
        uint256 unsETHRequestId = 1337; // not token id !
        uint256 swapAmount = 250 ether;
        vm.deal(payable(address(this)), 2000 ether);
        lpETH.deposit{ value: 1000 ether }(0);

        vm.mockCall(
            address(token1_adapter), abi.encodeCall(Adapter.minMaxAmount, ()), abi.encode(0 ether, 100_000 ether)
        );

        vm.mockCall(address(token1_adapter), abi.encodeCall(Adapter.totalStaked, ()), abi.encode(1000 ether));

        vm.mockCall(
            address(token1_adapter),
            abi.encodeCall(Adapter.requestWithdraw, (swapAmount)),
            abi.encode(unsETHRequestId, swapAmount)
        );

        token1.mint(address(this), 250 ether);
        token1.approve(address(lpETH), 250 ether);
        uint256 out = lpETH.swap(address(token1), 250 ether, 0);

        // ==== END SETUP ====

        // 1. Withdraw available amount, create request for remainder
        uint256 balanceBefore = address(this).balance;
        uint256 withdrawReqId = lpETH.withdraw(1000 ether, type(uint256).max);
        assertEq(address(this).balance - balanceBefore, 750 ether);
        assertEq(lpToken.balanceOf(address(this)), 0);
        WithdrawQueue.Request memory req = lpETH.getWithdrawRequest(withdrawReqId);
        assertEq(req.amount, 250 ether);
        assertEq(req.account, payable(address(this)));

        // 2. claim remainder
        // ==== SETUP ====
        // Mock finalize the request on the adapter
        // Redeem the UnsETH in the queue

        vm.mockCall(address(token1_adapter), abi.encodeCall(Adapter.isFinalized, (unsETHRequestId)), abi.encode(true));
        vm.mockCall(
            address(token1_adapter), abi.encodeCall(Adapter.claimWithdraw, (unsETHRequestId)), abi.encode(250 ether)
        );

        // deal the funds for the unlock
        // they are not actually transferred since the call to
        // the adapter is mocked
        vm.deal(payable(address(unsETH)), 250 ether);
        lpETH.redeemUnlock();
        // ==== END SETUP =====

        uint256 claimable = lpETH.getClaimableForWithdrawRequest(withdrawReqId);
        // Will equal the amount of the swap
        // since the amount that gets replenished for withdrawal requests
        // is the original swap amount minus the fee charged
        assertEq(claimable, out);
        balanceBefore = address(this).balance;
        lpETH.claimWithdrawRequest(withdrawReqId);
        assertEq(address(this).balance - balanceBefore, out);

        vm.deal(payable(address(lpETH)), 250 ether);
        claimable = lpETH.getClaimableForWithdrawRequest(withdrawReqId);
        assertEq(claimable, 0);
        vm.expectRevert(abi.encodeWithSelector(WithdrawQueue.NoClaimableETH.selector));
        claimable = lpETH.claimWithdrawRequest(withdrawReqId);

        // TODO: events
    }

    function test_swap_quote() public {
        // ===== SETUP =====
        uint256 unsETHRequestId = 1337; // not token id !
        uint256 swapAmount = 250 ether;
        vm.deal(payable(address(this)), 2000 ether);
        lpETH.deposit{ value: 1000 ether }(0);

        vm.mockCall(
            address(token1_adapter), abi.encodeCall(Adapter.minMaxAmount, ()), abi.encode(0 ether, 100_000 ether)
        );

        vm.mockCall(address(token1_adapter), abi.encodeCall(Adapter.totalStaked, ()), abi.encode(1000 ether));

        vm.mockCall(
            address(token1_adapter),
            abi.encodeCall(Adapter.requestWithdraw, (swapAmount)),
            abi.encode(unsETHRequestId, swapAmount)
        );

        token1.mint(address(this), 250 ether);
        // ==== END SETUP ====
        uint256 quote_out = lpETH.quote(address(token1), swapAmount);
        token1.approve(address(lpETH), swapAmount);
        uint256 eth_balance_before = address(this).balance;
        uint256 token1_balance_before = token1.balanceOf(address(this));
        uint256 out = lpETH.swap(address(token1), swapAmount, 0);

        assertTrue(out < swapAmount);
        assertEq(quote_out, out);
        assertEq(address(this).balance - eth_balance_before, out);
        assertEq(token1_balance_before - token1.balanceOf(address(this)), swapAmount);

        uint256 tokenId = uint256(keccak256(abi.encodePacked(address(token1), unsETHRequestId)));
        UnsETH.Request memory metadata = unsETH.getRequest(tokenId);
        assertEq(metadata.amount, swapAmount);
        assertEq(metadata.derivative, address(token1));
        assertEq(metadata.requestId, unsETHRequestId);
        assertEq(metadata.createdAt, block.timestamp);
        assertEq(unsETH.ownerOf(tokenId), address(lpETH));

        // TODO: check events
        // TODO: check amount
    }

    function test_batch_buyUnlock() public {
        uint256 unsETHRequestId = 1337; // not token id !
        uint256 swapAmount = 250 ether;
        vm.deal(payable(address(this)), 2000 ether);
        lpETH.deposit{ value: 1000 ether }(0);

        vm.mockCall(
            address(token1_adapter), abi.encodeCall(Adapter.minMaxAmount, ()), abi.encode(0 ether, 100_000 ether)
        );

        vm.mockCall(address(token1_adapter), abi.encodeCall(Adapter.totalStaked, ()), abi.encode(1000 ether));

        vm.mockCall(
            address(token1_adapter),
            abi.encodeCall(Adapter.requestWithdraw, (swapAmount)),
            abi.encode(unsETHRequestId, swapAmount)
        );

        token1.mint(address(this), 250 ether);
        token1.approve(address(lpETH), 200 ether);
        for (uint256 i = 0; i < 5; i++) {
            vm.mockCall(
                address(token1_adapter), abi.encodeCall(Adapter.requestWithdraw, (10 ether)), abi.encode(i, 10 ether)
            );
            lpETH.swap(address(token1), 10 ether, 0);

            vm.mockCall(address(token1_adapter), abi.encodeCall(Adapter.isFinalized, (i)), abi.encode(false));
        }

        // 50 ETH in unlocks pending

        // try to buy 50 ETH with 10 ETH
        vm.expectRevert(abi.encodeWithSelector(LpETHEvents.ErrorInsufficientAmount.selector));
        lpETH.batchBuyUnlock{ value: 10 ether }(5, uint256(keccak256(abi.encodePacked(token1, uint256(4)))));

        // now try with 50 ETH
        lpETH.batchBuyUnlock{ value: 50 ether }(5, uint256(keccak256(abi.encodePacked(token1, uint256(4)))));
    }
}
