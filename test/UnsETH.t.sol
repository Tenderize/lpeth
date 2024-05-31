pragma solidity >=0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UnsETH } from "@/unsETH/UnsETH.sol";
import { Registry } from "@/Registry.sol";
import { Renderer } from "@/unsETH/Renderer.sol";
import { ERC721Receiver } from "@/utils/ERC721Receiver.sol";
import { Adapter } from "@/adapters/Adapter.sol";

import { ERC721 } from "solady/tokens/ERC721.sol";
import { MockERC20 } from "./helpers/MockERC20.sol";

contract UnsETHTest is Test, ERC721Receiver {
    address registry = vm.addr(123);
    address adapter = vm.addr(456);
    UnsETH unsETH;
    MockERC20 myETH; // derivative token

    receive() external payable { }

    function setUp() public {
        vm.etch(registry, bytes("code"));
        vm.etch(adapter, bytes("code"));
        address renderer = address(new Renderer());
        address unsETH_impl = address(new UnsETH(registry, renderer));
        unsETH = UnsETH(payable(address(new ERC1967Proxy(unsETH_impl, ""))));
        unsETH.initialize();

        myETH = new MockERC20("MyETH", "myETH");
        myETH.mint(address(this), 1000 ether);
        vm.mockCall(registry, abi.encodeWithSignature("adapters(address)", (address(myETH))), abi.encode(adapter));
    }

    function test_name() public view {
        assertEq(unsETH.name(), "Unstaking ETH");
    }

    function test_symbol() public view {
        assertEq(unsETH.symbol(), "unsETH");
    }

    function test_owner() public view {
        assertEq(unsETH.owner(), address(this));
    }

    function test_requestWithdraw() public {
        uint256 amount = 10 ether;
        myETH.approve(address(unsETH), amount);
        uint256 expectedRequestId = 1337;
        uint256 expectedAmount = 9 ether;

        vm.mockCall(
            adapter, abi.encodeCall(Adapter.requestWithdraw, (amount)), abi.encode(expectedRequestId, expectedAmount)
        );

        (uint256 tokenId, uint256 outAmount) = unsETH.requestWithdraw(address(myETH), amount);

        uint256 expectedTokenId = uint256(keccak256(abi.encodePacked(address(myETH), expectedRequestId)));
        assertEq(tokenId, expectedTokenId);
        assertEq(outAmount, expectedAmount);
        (uint256 id, uint256 _amount, uint256 createdAt, address derivative) = unsETH.metadata(tokenId);
        assertEq(id, expectedRequestId);
        assertEq(_amount, expectedAmount);
        assertEq(createdAt, block.timestamp);
        assertEq(derivative, address(myETH));

        assertEq(unsETH.ownerOf(tokenId), address(this));
    }

    function test_claimWithdraw() public {
        uint256 amount = 10 ether;
        myETH.approve(address(unsETH), amount);
        uint256 expectedRequestId = 1337;
        uint256 expectedAmount = 9 ether;
        vm.deal(address(unsETH), 9 ether);

        uint256 balanceBefore = address(this).balance;
        vm.mockCall(
            adapter, abi.encodeCall(Adapter.requestWithdraw, (amount)), abi.encode(expectedRequestId, expectedAmount)
        );

        (uint256 tokenId, uint256 outAmount) = unsETH.requestWithdraw(address(myETH), amount);

        vm.mockCall(adapter, abi.encodeCall(Adapter.claimWithdraw, (expectedRequestId)), abi.encode(outAmount));

        assertEq(unsETH.claimWithdraw(tokenId), expectedAmount);
        assertEq(unsETH.balanceOf(address(this)), 0);
        assertEq(address(this).balance - balanceBefore, 9 ether);
        vm.expectRevert(abi.encodeWithSelector(ERC721.TokenDoesNotExist.selector));
        assertEq(unsETH.ownerOf(tokenId), address(0));
    }

    function test_isFinalized() public {
        uint256 amount = 10 ether;
        myETH.approve(address(unsETH), amount);
        uint256 expectedRequestId = 1337;
        uint256 expectedAmount = 9 ether;

        vm.mockCall(
            adapter, abi.encodeCall(Adapter.requestWithdraw, (amount)), abi.encode(expectedRequestId, expectedAmount)
        );

        (uint256 tokenId,) = unsETH.requestWithdraw(address(myETH), amount);

        vm.mockCall(adapter, abi.encodeCall(Adapter.isFinalized, (expectedRequestId)), abi.encode(false));

        assertFalse(unsETH.isFinalized(tokenId));

        vm.mockCall(adapter, abi.encodeCall(Adapter.isFinalized, (expectedRequestId)), abi.encode(true));

        assertTrue(unsETH.isFinalized(tokenId));
    }

    function test_minMax() public {
        uint256 min = 1 ether;
        uint256 max = 10 ether;

        vm.mockCall(adapter, abi.encodeCall(Adapter.minMaxAmount, ()), abi.encode(min, max));

        (uint256 _min, uint256 _max) = unsETH.minMaxAmount(address(myETH));
        assertEq(_min, min);
        assertEq(_max, max);
    }
}
