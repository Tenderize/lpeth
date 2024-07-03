pragma solidity ^0.8.25;

import { LpETH } from "@/lpETH/LpETH.sol";
import { ERC20 } from "@solady/tokens/ERC20.sol";
import { SafeTransferLib } from "@solady/utils/SafeTransferLib.sol";
import { STETH_TOKEN } from "@/adapters/stETH/StETHAdapter.sol";
import { EETH_TOKEN } from "@/adapters/eETH/EETHAdapter.sol";

address constant WRAPPED_STETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
address constant WRAPPED_EETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;

LpETH constant LPETH = LpETH(payable(address(2)));

interface Unwrap {
    function unwrap(uint256 amount) external returns (uint256);
}

contract SwapRouter {
    using SafeTransferLib for address;

    receive() external payable { }

    function swap(address tokenIn, uint256 amount, uint256 minOut) external returns (uint256 out) {
        tokenIn.safeTransferFrom(msg.sender, address(this), amount);
        if (tokenIn == WRAPPED_STETH || tokenIn == WRAPPED_EETH) {
            (tokenIn, amount) = _handleUnwrap(tokenIn, amount);
        }
        out = LPETH.swap(tokenIn, amount, minOut);
        payable(msg.sender).transfer(out);
    }

    function _handleUnwrap(
        address tokenIn,
        uint256 amount
    )
        internal
        returns (address unwrappedToken, uint256 unwrappedAmount)
    {
        unwrappedAmount = Unwrap(tokenIn).unwrap(amount);
        if (tokenIn == WRAPPED_STETH) {
            unwrappedToken = STETH_TOKEN;
        }
        if (tokenIn == WRAPPED_EETH) {
            unwrappedToken = EETH_TOKEN;
        }
    }
}
