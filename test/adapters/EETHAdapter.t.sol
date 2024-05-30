pragma solidity >=0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { EETHAdapter, EETH_TOKEN } from "@/adapters/eETH/EETHAdapter.sol";
import { ERC721Receiver } from "@/utils/ERC721Receiver.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";
import { AdapterDelegateCall } from "@/adapters/Adapter.sol";

address constant EETH_HOLDER = 0x22162DbBa43fE0477cdC5234E248264eC7C6EA7c;

//   tokenId 18143
//   amountExpected 99999999999999999999
//   totalStaked 1283949800110909723568459

contract EETHAdapterTest is Test, ERC721Receiver {
    EETHAdapter adapter;

    using AdapterDelegateCall for EETHAdapter;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC"), 19_847_895);
        adapter = new EETHAdapter();
        vm.startPrank(EETH_HOLDER);
        ERC20(EETH_TOKEN).transfer(address(this), 1000 ether);
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
