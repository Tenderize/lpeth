pragma solidity >=0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { METHAdapter, METH_TOKEN, STAKING } from "@/adapters/mETH/METHAdapter.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";
import { AdapterDelegateCall } from "@/adapters/Adapter.sol";

address constant METH_HOLDER = 0x78605Df79524164911C144801f41e9811B7DB73D;

// at this block height
//  tokenId 1601
// amountExpected 103241474194764736617

contract METHAdapterTest is Test {
    METHAdapter adapter;

    using AdapterDelegateCall for METHAdapter;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC"), 19_847_895);
        adapter = new METHAdapter();
        vm.startPrank(METH_HOLDER);
        ERC20(METH_TOKEN).transfer(address(this), 1000 ether);
        vm.stopPrank();
    }

    function test_request_and_claim() public {
        bytes memory data = adapter._delegatecall(abi.encodeWithSelector(adapter.requestWithdraw.selector, 100 ether));
        (uint256 tokenId, uint256 amountExpected) = abi.decode(data, (uint256, uint256));
        console.log("tokenId %s", tokenId);
        console.log("amountExpected %s", amountExpected);
        console.log("totalStaked %s", adapter.totalStaked());
        assertFalse(adapter.isFinalized(tokenId));
    }
}
