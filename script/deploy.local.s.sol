pragma solidity >=0.8.20;

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
    bytes32 salt = bytes32(uint256(1));

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        LPToken lpToken = new LPToken();

        address registry_impl = address(new Registry{ salt: salt }());
        Registry registryProxy = Registry(address(new ERC1967Proxy{ salt: salt }(address(registry_impl), "")));
        registryProxy.initialize();
        console2.log("Registry Implementation: %s", registry_impl);
        console2.log("Registry Proxy: %s", address(registryProxy));

        address renderer = address(new Renderer());
        address unsETH_impl = address(new UnsETH{ salt: salt }(address(registryProxy), renderer));
        UnsETH unsETHProxy = UnsETH(payable(address(new ERC1967Proxy{ salt: salt }(unsETH_impl, ""))));
        unsETHProxy.initialize();
        console2.log("UnsETH Implementation: %s", unsETH_impl);
        console2.log("UnsETH Proxy: %s", address(unsETHProxy));

        ConstructorConfig memory config =
            ConstructorConfig({ registry: registryProxy, lpToken: lpToken, unsETH: unsETHProxy, treasury: address(0) });

        address lpETH_impl = address(new LpETH{ salt: salt }(config));
        LpETH lpETHProxy = LpETH(payable(address(new ERC1967Proxy{ salt: salt }(lpETH_impl, ""))));
        lpETHProxy.initialize();
        console2.log("LPETH Implementation: %s", lpETH_impl);
        console2.log("LPETH Proxy: %s", address(lpETHProxy));
        console2.log("LP Token: %s", address(lpETHProxy.lpToken()));

        // Register and deploy adapters, send some funds
        Adapter eETHAdapter = new EETHAdapter();
        registryProxy.setAdapter(EETH_TOKEN, eETHAdapter);
        console2.log("EETH Adapter: %s", address(eETHAdapter));

        Adapter ethxAdapter = new ETHxAdapter();
        registryProxy.setAdapter(ETHx_TOKEN, ethxAdapter);
        console2.log("ETHx Adapter: %s", address(ethxAdapter));

        Adapter methAdapter = new METHAdapter();
        registryProxy.setAdapter(METH_TOKEN, methAdapter);
        console2.log("METH Adapter: %s", address(methAdapter));

        Adapter stETHAdapter = new StETHAdapter();
        registryProxy.setAdapter(STETH_TOKEN, stETHAdapter);
        console2.log("StETH Adapter: %s", address(stETHAdapter));

        vm.stopBroadcast();
    }
}
