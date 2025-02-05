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

// Token holders, to get some funds
import { EETH_HOLDER } from "@test/adapters/EETHAdapter.t.sol";
import { ETHx_HOLDER } from "@test/adapters/ETHxAdapter.t.sol";
import { METH_HOLDER } from "@test/adapters/METHAdapter.t.sol";
import { STETH_HOLDER } from "@test/adapters/StETHAdapter.t.sol";
import { SWETH_HOLDER } from "@test/adapters/SwETHAdapter.t.sol";

contract DeployLocal is Script {
    bytes32 salt = bytes32(0x76302e312e310000000000000000000000000000000000000000000000000000); // "v0.1.1"

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        LPToken lpToken = LPToken(0x70D48c92C443322d60327816c3dE04AE2f539E1A);
        Registry registry = Registry(0x809581787Ec6406b43e7Bd33E161D2D02653F8D9);
        UnsETH unsETH = UnsETH(payable(0x67cf179C3F8aCcaa30386cFe0C0305cF6cF30F6D));
        address treasury = 0x5542b58080FEE48dBE6f38ec0135cE9011519d96;

        ConstructorConfig memory config =
            ConstructorConfig({ registry: registry, lpToken: lpToken, unsETH: unsETH, treasury: treasury });

        address lpETH_impl = address(new LpETH{ salt: salt }(config));

        console2.log("LPETH Implementation: %s", lpETH_impl);

        vm.stopBroadcast();
    }
}
