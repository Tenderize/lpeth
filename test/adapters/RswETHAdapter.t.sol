pragma solidity >=0.8.25;

import { Test, console } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { IswETH, IswEXIT } from "@/adapters/swETH/ISwell.sol";
import { RswETHAdapter, RSWETH_TOKEN } from "@/adapters/rswETH/RswETHAdapter.sol";
import { ERC721Receiver } from "@/utils/ERC721Receiver.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";
import { AdapterDelegateCall } from "@/adapters/Adapter.sol";

address constant RSWETH_HOLDER = 0x3A0ee670EE34D889B52963bD20728dEcE4D9f8FE;

//   tokenId 6550
//   amountExpected 105898225379893452500
//   totalStaked 197304164246212470306573

contract SwEthAdapterTest is Test, ERC721Receiver {
    RswETHAdapter adapter;

    using AdapterDelegateCall for RswETHAdapter;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC"), 21_780_986);
        adapter = new RswETHAdapter();
        vm.startPrank(RSWETH_HOLDER);
        ERC20(RSWETH_TOKEN).transfer(address(this), 1000 ether);
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
