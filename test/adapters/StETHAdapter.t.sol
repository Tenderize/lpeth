pragma solidity >=0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { ERC721Receiver } from "@/utils/ERC721Receiver.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";
import { AdapterDelegateCall } from "@/adapters/Adapter.sol";
import { StETHAdapter, STETH_TOKEN } from "@/adapters/stETH/StETHAdapter.sol";

address constant STETH_HOLDER = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

//   tokenId 38290
//   amountExpected 100000000000000000000
//   totalStaked 9363673430668685685376298

contract ETHxAdapterTest is Test, ERC721Receiver {
    StETHAdapter adapter;

    using AdapterDelegateCall for StETHAdapter;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC"), 19_847_895);
        adapter = new StETHAdapter();
        vm.startPrank(STETH_HOLDER);
        ERC20(STETH_TOKEN).transfer(address(this), 1000 ether);
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
