pragma solidity >=0.8.20;

library AdapterDelegateCall {
    error AdapterDelegateCallFailed(string msg);

    function _delegatecall(Adapter adapter, bytes memory data) internal returns (bytes memory) {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returnData) = address(adapter).delegatecall(data);

        if (!success) {
            // Next 5 lines from https://ethereum.stackexchange.com/a/83577
            if (returnData.length < 68) revert AdapterDelegateCallFailed("");
            assembly {
                returnData := add(returnData, 0x04)
            }
            revert AdapterDelegateCallFailed(abi.decode(returnData, (string)));
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
