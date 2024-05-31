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

import { ERC20 } from "@solady/tokens/ERC20.sol";
import { Ownable } from "solady/auth/Ownable.sol";

contract LPToken is Ownable, ERC20 {
    constructor() ERC20() {
        _initializeOwner(msg.sender);
    }

    function name() public pure override returns (string memory) {
        return "lpETH";
    }

    function symbol() public pure override returns (string memory) {
        return "lpETH";
    }

    function mint(address to, uint256 value) public onlyOwner {
        _mint(to, value);
    }

    function burn(address from, uint256 value) public onlyOwner {
        _burn(from, value);
    }
}
