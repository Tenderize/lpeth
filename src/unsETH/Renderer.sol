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

pragma solidity >=0.8.20;

import { Initializable } from "@openzeppelin/upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/upgradeable/access/OwnableUpgradeable.sol";

import { Metadata } from "@/unsETH/UnsETH.sol";
import { Base64 } from "@/unsETH/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// import { Strings } from "openzeppelin-contracts/utils/Strings.sol";

// solhint-disable quotes

/// @title Renderer
/// @notice ERC721 metadata renderer for unlock tokens
/// @dev Renders SVG and JSON metadata for unlock tokens
/// @dev UUPS upgradeable contract

contract Renderer {
    using Strings for uint256;

    /**
     * @notice Returns the JSON metadata for a given unlock
     * @param data metadata for the token
     */
    function json(Metadata memory data) external pure returns (string memory) {
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    abi.encodePacked(
                        '{"name": "unsETH", "description": "unstaking ETH",',
                        '"attributes":[',
                        _serializeMetadata(data),
                        "]}"
                    )
                )
            )
        );
    }

    function svg(Metadata memory data) external pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<svg width="290" height="500" viewBox="0 0 290 500" xmlns="http://www.w3.org/2000/svg"',
                " xmlns:xlink='http://www.w3.org/1999/xlink'>",
                Base64.encode(
                    abi.encodePacked(
                        "<rect width='290px' height='500px' fill='#",
                        "000000",
                        "'/>",
                        "<text x='10' y='20'>",
                        data.derivative,
                        '</text><text x="10" y="40">',
                        data.amount.toString(),
                        '</text><text x="10" y="60">',
                        data.createdAt.toString(),
                        '</text><text x="10" y="80">',
                        data.requestId.toString(),
                        "</text>",
                        "</svg>"
                    )
                )
            )
        );
    }

    function _serializeMetadata(Metadata memory data) internal pure returns (string memory metadataString) {
        metadataString = string(
            abi.encodePacked(
                '{"trait_type": "createdAt", "value":',
                data.createdAt.toString(),
                "},",
                '{"trait_type": "amount", "value":',
                data.amount.toString(),
                "},",
                '{"trait_type": "derivative", "value":"',
                data.derivative,
                '"},',
                '{"trait_type": "requestId", "value":"',
                data.requestId,
                '"},'
            )
        );
    }
}
