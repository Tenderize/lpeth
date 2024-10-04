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
        address swap = 0xF506637B46AD84AF0e3883985Ba60e7fE3568395;

        LpETH(payable(swap)).deposit{ value: 1000 ether }(0);
        vm.stopBroadcast();
    }
}
