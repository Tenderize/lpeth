pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {
    PreLaunch,
    Config,
    Lockup,
    VotingEscrow,
    weth,
    CapExceeded,
    Inactive,
    InvalidDuration
} from "@/periphery/PreLaunch.sol";
import { WETH } from "@solady/tokens/WETH.sol";
import { UD60x18, ud } from "@prb/math/UD60x18.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { LpETH } from "@/lpETH/LpETH.sol";

contract PreLaunchHarness is PreLaunch {
    constructor(Config memory _config) PreLaunch(_config) { }

    function lpEthAddress() public view returns (address) {
        return lpEth;
    }

    function Harness_setLpEthreceived(uint256 _lpEthReceived) public {
        lpEthReceived = _lpEthReceived;
    }
}

contract PreLaunchTest is Test {
    PreLaunchHarness preLaunch;
    address owner = address(0x123);
    address depositor = address(0x456);
    address newLpEth = address(0x789);
    address newVotingEscrow = address(0xabc);

    Config config;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC"), 19_847_895);

        config = Config({
            cap: 100 ether,
            deadline: block.timestamp + 7 days,
            minLockup: 1,
            maxLockup: 52,
            epochLength: 1 weeks,
            minMultiplier: ud(1e17),
            maxMultiplier: ud(3e18),
            slope: ud(2e18)
        });

        address preLaunchImplementation = address(new PreLaunchHarness(config));

        preLaunch = PreLaunchHarness(payable(address(new ERC1967Proxy(address(preLaunchImplementation), ""))));

        preLaunch.initialize();

        preLaunch.transferOwnership(owner);

        vm.deal(depositor, 100 ether);
    }

    function testIsActive() public {
        assertTrue(preLaunch.isActive());
    }

    function testIsClaimable() public {
        assertFalse(preLaunch.isClaimable());
        vm.startPrank(owner);
        preLaunch.setVotingEscrow(newVotingEscrow);
        preLaunch.Harness_setLpEthreceived(1 ether);
        vm.stopPrank();
        assertTrue(preLaunch.isClaimable());
    }

    function testSetLpEth() public {
        vm.startPrank(owner);
        preLaunch.setLpEth(payable(newLpEth));
        assertEq(preLaunch.lpEthAddress(), newLpEth);
        vm.expectRevert();
        preLaunch.setLpEth(payable(newLpEth));
        vm.stopPrank();
    }

    function testSetVotingEscrow() public {
        vm.startPrank(owner);
        preLaunch.setVotingEscrow(newVotingEscrow);
        assertEq(preLaunch.votingEscrow(), newVotingEscrow);
        vm.expectRevert();
        preLaunch.setVotingEscrow(newVotingEscrow);
        vm.stopPrank();
    }

    function testMintLpEth() public {
        vm.startPrank(owner);
        preLaunch.setLpEth(payable(newLpEth));
        vm.warp(config.deadline + 1);
        vm.deal(address(preLaunch), 1 ether);
        vm.mockCall(newLpEth, abi.encodeWithSelector(LpETH.deposit.selector, 1 ether), abi.encode(1 ether));
        preLaunch.mintLpEth(1 ether);
        vm.stopPrank();
    }

    function testDepositETH() public {
        vm.startPrank(depositor);
        preLaunch.depositETH{ value: 1 ether }(4);
        Lockup memory lockup = preLaunch.lockup(depositor);
        assertEq(lockup.amount, 1 ether);
        assertEq(lockup.duration, 4);
        vm.stopPrank();
    }

    function testDepositWETH() public {
        address wethHolder = 0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E;
        vm.startPrank(wethHolder);
        WETH(weth).transfer(depositor, 1 ether);
        vm.stopPrank();

        vm.startPrank(depositor);
        WETH(weth).approve(address(preLaunch), 1 ether);
        preLaunch.depositWETH(1 ether, 4);
        Lockup memory lockup = preLaunch.lockup(depositor);
        assertEq(lockup.amount, 1 ether);
        assertEq(lockup.duration, 4);
        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(depositor);
        preLaunch.depositETH{ value: 1 ether }(4);
        preLaunch.withdraw(0.5 ether);
        Lockup memory lockup = preLaunch.lockup(depositor);
        assertEq(lockup.amount, 0.5 ether);
        vm.stopPrank();
    }

    function testChangeLockup() public {
        vm.startPrank(depositor);
        preLaunch.depositETH{ value: 1 ether }(4);
        preLaunch.changeLockup(8);
        Lockup memory lockup = preLaunch.lockup(depositor);
        assertEq(lockup.duration, 8);
        vm.stopPrank();
    }

    function testInvalidDuration() public {
        vm.startPrank(depositor);
        vm.expectRevert(abi.encodeWithSelector(InvalidDuration.selector));
        preLaunch.depositETH{ value: 1 ether }(0);
        vm.stopPrank();
    }

    function testInactiveDeposit() public {
        vm.warp(config.deadline + 1);
        vm.startPrank(depositor);
        vm.expectRevert(abi.encodeWithSelector(Inactive.selector));
        preLaunch.depositETH{ value: 1 ether }(4);
        vm.stopPrank();
    }

    function testCapExceeded() public {
        vm.deal(depositor, 101 ether);
        vm.startPrank(depositor);
        preLaunch.depositETH{ value: 50 ether }(4);
        vm.expectRevert(abi.encodeWithSelector(CapExceeded.selector));
        preLaunch.depositETH{ value: 51 ether }(4);
        vm.stopPrank();
    }
}
