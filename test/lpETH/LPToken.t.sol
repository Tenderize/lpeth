pragma solidity >=0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";

import { LPToken } from "@/lpETH/LPToken.sol";
import { Ownable } from "solady/auth/Ownable.sol";

contract LPTokenTest is Test {
    LPToken lpToken;

    function setUp() public {
        lpToken = new LPToken();
    }

    function test_name() public view {
        assertEq(lpToken.name(), "lpETH");
    }

    function test_symbol() public view {
        assertEq(lpToken.symbol(), "lpETH");
    }

    function test_owner() public view {
        assertEq(lpToken.owner(), address(this));
    }

    function test_mint() public {
        lpToken.mint(address(this), 1000);
        assertEq(lpToken.balanceOf(address(this)), 1000);
    }

    function test_mint_unauthorized() public {
        vm.startPrank(vm.addr(333));
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        lpToken.mint(address(this), 1000);
        vm.stopPrank();
    }

    function test_burn() public {
        lpToken.mint(address(this), 1000);
        lpToken.burn(address(this), 500);
        assertEq(lpToken.balanceOf(address(this)), 500);
    }

    function test_burn_unauthorized() public {
        lpToken.mint(address(this), 1000);
        vm.startPrank(vm.addr(333));
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        lpToken.burn(address(this), 500);
        vm.stopPrank();
    }
}
