pragma solidity >=0.8.20;

import { Script, console2 } from "forge-std/Script.sol";
import { UnsETH } from "@/unsETH/UnsETH.sol";
import { Renderer } from "@/unsETH/Renderer.sol";
import { LpETH } from "@/lpETH/LpETH.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";

// Adapters
import { Adapter } from "@/adapters/Adapter.sol";
import { EETHAdapter, EETH_TOKEN } from "@/adapters/eETH/EETHAdapter.sol";
import { ETHxAdapter, ETHx_TOKEN } from "@/adapters/ETHx/ETHxAdapter.sol";
import { METHAdapter, METH_TOKEN } from "@/adapters/mETH/METHAdapter.sol";
import { StETHAdapter, STETH_TOKEN } from "@/adapters/stETH/StETHAdapter.sol";
import { SwETHAdapter, SWETH_TOKEN } from "@/adapters/swETH/SwETHAdapter.sol";

// Token holders, to get some funds
import { EETH_HOLDER } from "@test/adapters/EETHAdapter.t.sol";
import { ETHx_HOLDER } from "@test/adapters/ETHxAdapter.t.sol";
import { METH_HOLDER } from "@test/adapters/METHAdapter.t.sol";
import { STETH_HOLDER } from "@test/adapters/StETHAdapter.t.sol";
import { SWETH_HOLDER } from "@test/adapters/SwETHAdapter.t.sol";

contract DeployLocal is Script {
    bytes32 salt = bytes32(uint256(1));

    function run() public {
        address me = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

        console2.log("balance", ERC20(EETH_TOKEN).balanceOf(me));

        console2.log("balance", ERC20(EETH_TOKEN).balanceOf(me));

        console2.log("balance", ERC20(EETH_TOKEN).balanceOf(me));

        console2.log("balance", ERC20(EETH_TOKEN).balanceOf(me));
    }
}
