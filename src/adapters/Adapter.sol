pragma solidity >=0.8.25;

import { console } from "forge-std/console.sol";

library AdapterDelegateCall {
    error AdapterDelegateCallFailed(string msg);

    function _delegatecall(Adapter adapter, bytes memory data) internal returns (bytes memory) {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returnData) = address(adapter).delegatecall(data);
        console.log("success %s", success);
        console.log("returnData %s", string(returnData));
        if (!success) {
            if (returnData.length < 4) {
                revert AdapterDelegateCallFailed("Unknown error occurred");
            }

            // Bubble up the full return data
            assembly {
                let returndata_size := mload(returnData)
                revert(add(returnData, 0x20), returndata_size)
            }
        }

        return returnData;
    }
}

interface Adapter {
    function previewWithdraw(uint256 amount) external view returns (uint256 amountExpected);
    function requestWithdraw(uint256 amount) external returns (uint256 tokenId, uint256 amountExpected);
    // TODO: for each adapter check if a cross-contract invocation to get this amount is more efficient
    // than fetching account balance before and after
    function claimWithdraw(uint256 tokenId) external returns (uint256 amount);
    function isFinalized(uint256 tokenId) external view returns (bool);
    function totalStaked() external view returns (uint256);
    function minMaxAmount() external view returns (uint256 min, uint256 max);
}
