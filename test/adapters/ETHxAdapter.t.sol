pragma solidity >=0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { ETHxAdapter, ETHx_TOKEN } from "@/adapters/ETHx/ETHxAdapter.sol";
import { ERC721Receiver } from "@/utils/ERC721Receiver.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";
import { AdapterDelegateCall } from "@/adapters/Adapter.sol";

address constant ETHx_HOLDER = 0x9d7eD45EE2E8FC5482fa2428f15C971e6369011d;

//   tokenId 1192
//   amountExpected 102925116334432543526
//   totalStaked 125990931924605434662214

contract ETHxAdapterTest is Test, ERC721Receiver {
    ETHxAdapter adapter;

    using AdapterDelegateCall for ETHxAdapter;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC"), 19_847_895);
        adapter = new ETHxAdapter();
        vm.startPrank(ETHx_HOLDER);
        ERC20(ETHx_TOKEN).transfer(address(this), 1000 ether);
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
