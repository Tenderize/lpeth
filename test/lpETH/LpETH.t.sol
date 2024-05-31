pragma solidity >=0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";

import { LpETH, LpETHEvents, ConstructorConfig } from "@/lpETH/LpETH.sol";
import { Registry } from "@/Registry.sol";
import { LPToken } from "@/lpETH/LPToken.sol";

import { MockERC20 } from "../helpers/MockERC20.sol";

contract LPETH_Harness is LpETH {
    constructor(ConstructorConfig memory config) LpETH(config) { }
}

contract LPETH_Test is Test {
    Registry registry;
    LPToken lpToken;
    MockERC20 token1;
    MockERC20 token2;
    LpETH lpETH;

    function setUp() public {
        token1 = new MockERC20("Token1", "T1", 18);
        token2 = new MockERC20("Token 2", "T2", 18);
        registry = new Registry();
        lpToken = new LPToken();
        ConstructorConfig memory config =
            ConstructorConfig({ registry: registry, lpToken: lpToken, unsETH: address(11), treasury: address(10) });
        lpETH = new LPETH_Harness(config);
        lpToken.transferOwnership(address(lpETH));
    }

    function test_deposit() public {
        vm.deal(payable(address(this)), 1000 ether);
        lpETH.deposit{ value: 1000 ether }(0);
        assertEq(lpToken.balanceOf(address(this)), 1000 ether);
        assertEq(lpToken.totalSupply(), 1000 ether);
        assertEq(lpETH.liabilities(), 1000 ether);
    }

    function test_deposit_errorSlippage() public {
        vm.deal(payable(address(this)), 1000 ether);
        vm.expectRevert(abi.encodeWithSelector(LpETHEvents.ErrorSlippage.selector, 1000 ether, 2000 ether));
        lpETH.deposit{ value: 1000 ether }(2000 ether);
    }
}
