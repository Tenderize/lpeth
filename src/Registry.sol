pragma solidity >=0.8.20;

import { OwnableUpgradeable } from "@openzeppelin/upgradeable/access/OwnableUpgradeable.sol";
import { Initializable } from "@openzeppelin/upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Adapter } from "@/adapters/Adapter.sol";

contract Registry is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    mapping(address asset => Adapter) public adapters;

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function setAdapter(address token, Adapter adapter) external onlyOwner {
        adapters[token] = adapter;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}
