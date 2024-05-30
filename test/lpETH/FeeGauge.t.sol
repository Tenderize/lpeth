pragma solidity >=0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";

import { LPETH, LpETHEvents, ConstructorConfig } from "@/LPETH.sol";
import { LPToken } from "@/LPToken.sol";
import { Registry } from "@/Registry.sol";

import { UD60x18, UNIT, ud } from "@prb/math/UD60x18.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract LPETH_FeeGauge_Test is Test {
    LPETH lpETH;

    function setUp() public {
        ConstructorConfig memory config = ConstructorConfig({
            registry: Registry(address(8)),
            lpToken: LPToken(address(9)),
            treasury: address(10),
            unsETH: address(11),
            withdrawQueue: address(12)
        });
        LPETH lpETH_impl = new LPETH(config);
        lpETH = LPETH(payable(address(new ERC1967Proxy(address(lpETH_impl), ""))));
        lpETH.initialize();
    }

    function test_setGauge() public {
        lpETH.setFeeGauge(address(this), UD60x18.wrap(0.76e18));
        assertEq(lpETH.getFeeGauge(address(this)).unwrap(), 0.76e18);
    }

    function test_setGauge_zero() public {
        vm.expectRevert(abi.encodeWithSelector(LpETHEvents.GaugeZero.selector));
        lpETH.setFeeGauge(address(this), ud(0));
    }

    function test_getGauge_unset() public view {
        assert(lpETH.getFeeGauge(address(this)).eq(UNIT));
    }
}
