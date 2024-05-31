pragma solidity >=0.8.20;

import { Script, console2 } from "forge-std/Script.sol";
import { Registry } from "@/Registry.sol";
import { UnsETH } from "@/unsETH/UnsETH.sol";
import { Renderer } from "@/unsETH/Renderer.sol";
import { LpETH } from "@/lpETH/LpETH.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";

contract DeployLocal is Script {
    bytes32 salt = bytes32(uint256(1));

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address swap = 0xB5A53938316E4a02c0d91F1b454E43583429e347;

        LpETH(payable(swap)).deposit{ value: 5000 ether }(0);
        vm.stopBroadcast();
    }
}
