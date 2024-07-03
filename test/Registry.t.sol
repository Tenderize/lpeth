// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "@/adapters/Adapter.sol";
import { Registry } from "@/Registry.sol";

import { UUPSUpgradeable } from "@openzeppelin/upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Proxy, ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { OwnableUpgradeable } from "@openzeppelin/upgradeable/access/OwnableUpgradeable.sol";

contract RegistryTest is Test {
    Registry private registry;
    address private owner;
    address private other;
    Adapter private adapter;

    function setUp() public {
        other = address(0x1234);
        vm.etch(other, bytes("code"));
        adapter = Adapter(vm.addr(0x5678));

        // Deploy the registry contract
        address registry_impl = address(new Registry());
        registry = Registry(payable(address(new ERC1967Proxy(registry_impl, ""))));

        // Initialize the registry contract
        registry.initialize();
    }

    function test_owner() public view {
        // Check that the owner is set correctly
        assertEq(registry.owner(), address(this), "Owner should be set to the deployer");
    }

    function test_setAdapter() public {
        // Set an adapter
        registry.setAdapter(other, adapter);

        // Verify the adapter was set correctly
        assertEq(address(registry.adapters(other)), address(adapter), "Adapter should be set correctly");
    }

    function test_setAdapter_unauthorized() public {
        // Try to set an adapter from a non-owner address
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, other));
        registry.setAdapter(other, adapter);
    }
}
