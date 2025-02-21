pragma solidity >=0.8.25;

import { Script, console2 } from "forge-std/Script.sol";
import { Registry } from "@/Registry.sol";
import { UnsETH } from "@/unsETH/UnsETH.sol";
import { Renderer } from "@/unsETH/Renderer.sol";
import { LpETH, ConstructorConfig } from "@/lpETH/LpETH.sol";
import { LPToken } from "@/lpETH/LPToken.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";

// Adapters
import { Adapter } from "@/adapters/Adapter.sol";
import { EETHAdapter, EETH_TOKEN } from "@/adapters/eETH/EETHAdapter.sol";
import { ETHxAdapter, ETHx_TOKEN } from "@/adapters/ETHx/ETHxAdapter.sol";
import { METHAdapter, METH_TOKEN } from "@/adapters/mETH/METHAdapter.sol";
import { StETHAdapter, STETH_TOKEN } from "@/adapters/stETH/StETHAdapter.sol";
import { SwETHAdapter, SWETH_TOKEN } from "@/adapters/swETH/SwETHAdapter.sol";
import { RsETHAdapter, RSETH_TOKEN } from "@/adapters/rsETH/RsETHAdapter.sol";
import { RswETHAdapter, RSWETH_TOKEN } from "@/adapters/rswETH/RswETHAdapter.sol";

// Token holders, to get some funds
import { EETH_HOLDER } from "@test/adapters/EETHAdapter.t.sol";
import { ETHx_HOLDER } from "@test/adapters/ETHxAdapter.t.sol";
import { METH_HOLDER } from "@test/adapters/METHAdapter.t.sol";
import { STETH_HOLDER } from "@test/adapters/StETHAdapter.t.sol";
import { SWETH_HOLDER } from "@test/adapters/SwETHAdapter.t.sol";

contract DeployNewAdapter is Script {
    bytes32 salt = bytes32(0x76302e312e300000000000000000000000000000000000000000000000000000); // "v0.1.0"

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Adapter rsETHAdapter = new RsETHAdapter();
        console2.log("RsETH Adapter: %s", address(rsETHAdapter));

        Adapter rswETHAdapter = new RswETHAdapter();
        console2.log("RswETH Adapter: %s", address(rswETHAdapter));

        vm.stopBroadcast();
    }
}
