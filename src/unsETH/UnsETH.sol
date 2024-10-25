// SPDX-License-Identifier: MIT
//
//  _____              _           _
// |_   _|            | |         (_)
//   | | ___ _ __   __| | ___ _ __ _ _______
//   | |/ _ \ '_ \ / _` |/ _ \ '__| |_  / _ \
//   | |  __/ | | | (_| |  __/ |  | |/ /  __/
//   \_/\___|_| |_|\__,_|\___|_|  |_/___\___|
//
// Copyright (c) Tenderize Labs Ltd

import { ERC721 } from "solady/tokens/ERC721.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { Initializable } from "@openzeppelin/upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/upgradeable/access/OwnableUpgradeable.sol";

import { Renderer } from "@/unsETH/Renderer.sol";
import { Registry } from "@/Registry.sol";
import { ERC721Receiver } from "@/utils/ERC721Receiver.sol";
import { Adapter, AdapterDelegateCall } from "@/adapters/Adapter.sol";

pragma solidity >=0.8.25;

// solhint-disable quotes

contract UnsETH is Initializable, UUPSUpgradeable, OwnableUpgradeable, ERC721, ERC721Receiver {
    /// @title Unlocks
    /// @notice ERC721 contract for unlock tokens
    /// @dev Creates an NFT for staked tokens pending unlock. Each Unlock has an amount and a maturity date.

    struct Request {
        uint256 requestId; // request id
        uint256 amount; // expected amount to receive
        uint256 createdAt; // block timestamp
        address derivative; // address of the derivative LST/LRT
    }

    address private immutable LPETH;
    Registry private immutable REGISTRY;
    Renderer private immutable RENDERER;
    mapping(uint256 => Request) private requests;

    error NotOwnerOf(uint256 tokenId, address owner, address sender);
    error InvalidID();

    constructor(address registry, address renderer) ERC721() {
        REGISTRY = Registry(registry);
        RENDERER = Renderer(renderer);
        _disableInitializers();
    }

    function initialize() external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    fallback() external payable { }
    receive() external payable { }

    function name() public pure override returns (string memory) {
        return "Unstaking ETH";
    }

    function symbol() public pure override returns (string memory) {
        return "unsETH";
    }

    function requestWithdraw(
        address asset,
        uint256 amount
    )
        external
        returns (uint256 tokenId, uint256 amountExpected)
    {
        SafeTransferLib.safeTransferFrom(asset, msg.sender, address(this), amount);

        uint256 requestId;
        (requestId, amountExpected) = abi.decode(
            AdapterDelegateCall._delegatecall(
                REGISTRY.adapters(asset), abi.encodeWithSelector(Adapter.requestWithdraw.selector, amount)
            ),
            (uint256, uint256)
        );

        Request memory _metadata =
            Request({ requestId: requestId, amount: amountExpected, createdAt: block.timestamp, derivative: asset });
        tokenId = uint256(keccak256(abi.encodePacked(asset, requestId)));
        requests[tokenId] = _metadata;
        _safeMint(msg.sender, tokenId);
    }

    function claimWithdraw(uint256 tokenId) external returns (uint256 amount) {
        if (ownerOf(tokenId) != msg.sender) {
            revert NotOwnerOf(tokenId, ownerOf(tokenId), msg.sender);
        }

        Request memory _metadata = requests[tokenId];

        amount = abi.decode(
            AdapterDelegateCall._delegatecall(
                REGISTRY.adapters(_metadata.derivative),
                abi.encodeWithSelector(Adapter.claimWithdraw.selector, _metadata.requestId)
            ),
            (uint256)
        );

        _burn(tokenId);
        delete requests[tokenId];
        SafeTransferLib.safeTransferETH(msg.sender, amount);
    }

    function isFinalized(uint256 tokenId) external view returns (bool) {
        Request memory _metadata = requests[tokenId];
        return REGISTRY.adapters(_metadata.derivative).isFinalized(_metadata.requestId);
    }

    function minMaxAmount(address asset) external view returns (uint256 min, uint256 max) {
        return REGISTRY.adapters(asset).minMaxAmount();
    }

    function getRequest(uint256 tokenId) external view returns (Request memory) {
        return requests[tokenId];
    }

    /**
     * @notice Returns the tokenURI of an unlock token
     * @param tokenId ID of the unlock token
     * @return tokenURI of the unlock token
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (ownerOf(tokenId) == address(0)) {
            revert InvalidID();
        }

        Request memory data = requests[tokenId];
        return RENDERER.json(data);
    }

    ///@dev required by the OZ UUPS module
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner { }
}
