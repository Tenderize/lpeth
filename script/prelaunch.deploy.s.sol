pragma solidity >=0.8.25;

import { Script, console2 } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UD60x18 } from "@prb/math/UD60x18.sol";
import { PreLaunch, Config } from "@/periphery/PreLaunch.sol";

contract DeployPrelaunch is Script {
    bytes32 salt = bytes32(uint256(2));

    address SAFE = 0x5542b58080FEE48dBE6f38ec0135cE9011519d96;

    function run() public {
        Config memory cfg = Config({
            cap: 80_000 ether,
            deadline: 1_728_746_087,
            minLockup: 1,
            maxLockup: 52,
            epochLength: 604_800,
            minMultiplier: UD60x18.wrap(1e17),
            maxMultiplier: UD60x18.wrap(5e18),
            slope: UD60x18.wrap(2.5e18)
        });
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address prelaunch_impl = address(new PreLaunch{ salt: salt }(cfg));
        // PreLaunch prelaunchProxy = PreLaunch(payable(address(new ERC1967Proxy{ salt: salt }(prelaunch_impl, ""))));
        //  prelaunchProxy.initialize();

        // prelaunchProxy.transferOwnership(SAFE);

        // console2.log("PreLaunch Proxy: %s", address(prelaunchProxy));
        console2.log("PreLaunch Implementation: %s", prelaunch_impl);
    }
}
