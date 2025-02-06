pragma solidity >=0.8.25;

import { Test, console } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { RsETHAdapter, RSETH_TOKEN } from "@/adapters/rsETH/RsETHAdapter.sol";
import { ERC721Receiver } from "@/utils/ERC721Receiver.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";
import { AdapterDelegateCall } from "@/adapters/Adapter.sol";
import { Withdrawals, WITHDRAWALS, ETH_TOKEN } from "@/adapters/rsETH/IKelp.sol";

address constant RSETH_HOLDER = 0x22162DbBa43fE0477cdC5234E248264eC7C6EA7c;

//   tokenId 18143
//   amountExpected 99999999999999999999
//   totalStaked 1283949800110909723568459

contract RsETHAdapterTest is Test, ERC721Receiver {
    RsETHAdapter adapter;

    using AdapterDelegateCall for RsETHAdapter;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC"), 21_280_986);
        adapter = new RsETHAdapter();
        vm.startPrank(RSETH_HOLDER);
        ERC20(RSETH_TOKEN).transfer(address(this), 6 ether);
        vm.stopPrank();
    }

    function test_request_and_claim() public {
        uint256 available = Withdrawals(WITHDRAWALS).getAvailableAssetAmount(ETH_TOKEN);
        console.log("available ETH for withdrawals %", available);
        bytes memory data = adapter._delegatecall(abi.encodeWithSelector(adapter.requestWithdraw.selector, 5 ether));
        (uint256 tokenId, uint256 amountExpected) = abi.decode(data, (uint256, uint256));
        console.log("tokenId %s", tokenId);
        console.log("amountExpected %s", amountExpected);
        console.log("totalStaked %s", adapter.totalStaked());
        assertFalse(adapter.isFinalized(tokenId));
    }
}
