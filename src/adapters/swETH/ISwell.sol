pragma solidity >=0.8.25;

struct WithdrawRequest {
    uint256 amount;
    uint256 lastTokenIdProcessed; // last token id processed at the time the request was created
    // when claiming (finalizing here) it will perform a binary search between lastTokenIdProcessed and our tokenid
    uint256 rateWhenCreated;
}

uint256 constant WITHDRAW_REQUEST_MAX = 0;
uint256 constant WITHDRAW_REQUEST_MIN = 0;

interface IswEXIT {
    // this doesn't return the id, so we need to get the id seperately
    function createWithdrawRequest(uint256 amount) external;
    function getLastTokenIdCreated() external view returns (uint256);

    // this doesn't return anything and getting the processed rate is very expensive
    // so instead we can just get balance before and after from the adapter
    function finalizeWithdrawal(uint256 tokenId) external;

    //  isFinalized = lastTokenIdProcessd >= tokenId
    function getLastTokenIdProcessed() external view returns (uint256);
    // probably don't need this
    function withdrawalRequests(uint256 tokenId) external view returns (WithdrawRequest memory);
}

interface IswETH {
    // uses ud60x18 under the hood
    function getRate() external view returns (uint256);
    function totalSupply() external view returns (uint256);

    // totalStaked will be total_supply * rate / 1e18
    // or if using ud60x18 wrap(total_supply).mul(wrap(rate)).unwrap()
}
