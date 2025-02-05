pragma solidity >=0.8.25;

import { Test, console } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { RsETHAdapter, RSETH_TOKEN } from "@/adapters/rsETH/RsETHAdapter.sol";
import { ERC721Receiver } from "@/utils/ERC721Receiver.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";
import { AdapterDelegateCall } from "@/adapters/Adapter.sol";

address constant RSETH_HOLDER = 0x43594da5d6A03b2137a04DF5685805C676dEf7cB;

//   tokenId 18143
//   amountExpected 99999999999999999999
//   totalStaked 1283949800110909723568459

contract RsETHAdapterTest is Test, ERC721Receiver {
    RsETHAdapter adapter;

    using AdapterDelegateCall for RsETHAdapter;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC"));
        adapter = new RsETHAdapter();
        vm.startPrank(RSETH_HOLDER);
        ERC20(RSETH_TOKEN).transfer(address(this), 10 ether);
        vm.stopPrank();
    }

    function test_request_and_claim() public {
        bytes memory data = adapter._delegatecall(abi.encodeWithSelector(adapter.requestWithdraw.selector, 10 ether));
        (uint256 tokenId, uint256 amountExpected) = abi.decode(data, (uint256, uint256));
        console.log("tokenId %s", tokenId);
        console.log("amountExpected %s", amountExpected);
        console.log("totalStaked %s", adapter.totalStaked());
        assertFalse(adapter.isFinalized(tokenId));
    }
}
