pragma solidity >=0.8.25;

import { Test, console } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { SwETHAdapter, IswETH, IswEXIT, SWETH_TOKEN, SWEXIT } from "@/adapters/swETH/SwETHAdapter.sol";
import { ERC721Receiver } from "@/utils/ERC721Receiver.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";
import { AdapterDelegateCall } from "@/adapters/Adapter.sol";

address constant SWETH_HOLDER = 0x38D43a6Cb8DA0E855A42fB6b0733A0498531d774;

//   tokenId 6550
//   amountExpected 105898225379893452500
//   totalStaked 197304164246212470306573

contract SwEthAdapterTest is Test, ERC721Receiver {
    SwETHAdapter adapter;

    using AdapterDelegateCall for SwETHAdapter;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC"), 19_847_895);
        adapter = new SwETHAdapter();
        vm.startPrank(SWETH_HOLDER);
        ERC20(SWETH_TOKEN).transfer(address(this), 1000 ether);
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
