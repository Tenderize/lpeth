pragma solidity >=0.8.25;

import { Script, console2 } from "forge-std/Script.sol";
import { Registry } from "@/Registry.sol";
import { UnsETH } from "@/unsETH/UnsETH.sol";
import { Renderer } from "@/unsETH/Renderer.sol";
import { LpETH } from "@/lpETH/LpETH.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";

contract AddLiquidity is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address swap = 0xF3a75E087A92770b4150fFF14c6d36FB07796252;

        LpETH(payable(swap)).deposit{ value: 0.5 ether }(0.5 ether);
        vm.stopBroadcast();
    }
}
