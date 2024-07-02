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

import { Registry } from "@/Registry.sol";
import { LPToken } from "@/lpETH/LPToken.sol";
import { UnsETH } from "@/unsETH/UnsETH.sol";
import { UnsETHQueue } from "@/lpETH/UnsETHQueue.sol";
import { Adapter } from "@/adapters/Adapter.sol";
import { WithdrawQueue } from "@/lpETH/WithdrawQueue.sol";
import { ERC721Receiver } from "@/utils/ERC721Receiver.sol";

import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { Multicallable } from "solady/utils/Multicallable.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { SelfPermit } from "@/utils/SelfPermit.sol";

import { UD60x18, ud, UNIT as UNIT_60x18, ZERO as ZERO_60x18 } from "@prb/math/UD60x18.sol";

import { OwnableUpgradeable } from "@openzeppelin/upgradeable/access/OwnableUpgradeable.sol";
import { Initializable } from "@openzeppelin/upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/upgradeable/proxy/utils/UUPSUpgradeable.sol";

// Time for which unsETH can be bought from the pool
// Since at the moment it won't be possible to determine
// The maturity of certain unsETH tokens, we will set this to 3.5 days.
// This value should be lower than the common advertised unstaking time of supported protocols.
// ALTERNATIVELY: in the future we could use an oracle that determines the current withdrawal queue length
// which should account for both partial and full withdrawals, but not for any potential instant liquid funds
// some protocols might keep on hand. This is why "buyUnlock" should also always check if an unlock has been finalized.

uint256 constant UNSETH_EXPIRATION_TIME = 3 days + 12 hours;
UD60x18 constant BASE_FEE = UD60x18.wrap(0.0005e18);
UD60x18 constant K = UD60x18.wrap(4.5e18);
UD60x18 constant RELAYER_CUT = UD60x18.wrap(0.025e18);
UD60x18 constant TREASURY_CUT = UD60x18.wrap(0.2e18);
UD60x18 constant MIN_LP_CUT = UD60x18.wrap(0.2e18);

struct ConstructorConfig {
    Registry registry;
    LPToken lpToken;
    UnsETH unsETH;
    address treasury;
}

struct SwapParams {
    UD60x18 u;
    UD60x18 U;
    UD60x18 s;
    UD60x18 S;
}

abstract contract LpETHEvents {
    error ErrorNotFinalized(uint256 tokenId);
    error ErrorIsFinalized(uint256 tokenId);
    error ErrorInvalidAsset(address asset);
    error UnexpectedTokenId();
    error ErrorSlippage(uint256 out, uint256 minOut);
    error ErrorDepositSharesZero();
    error ErrorRecoveryMode();
    error GaugeZero();
    error ErrorInsufficientAmount();

    event Deposit(address indexed from, uint256 amount, uint256 lpSharesMinted);
    event Withdraw(address indexed to, uint256 amount, uint256 lpSharesBurnt, uint256 requestId);
    event ClaimWithdrawRequest(uint256 indexed requestId, address indexed to, uint256 amount);
    event Swap(address indexed caller, address indexed asset, uint256 amountIn, uint256 fee, uint256 unlockId);
    event UnlockBought(address indexed caller, uint256 tokenId, uint256 amount, uint256 reward, uint256 lpFees);
    event UnlockRedeemed(address indexed relayer, uint256 tokenId, uint256 amount, uint256 reward, uint256 lpFees);
    event BatchUnlockRedeemed(
        address indexed relayer, uint256 amount, uint256 reward, uint256 lpFees, uint256[] tokenIds
    );
    event BatchUnlockBought(address indexed caller, uint256 amount, uint256 reward, uint256 lpFees, uint256[] tokenIds);
    event RelayerRewardsClaimed(address indexed relayer, uint256 rewards);
}

abstract contract LpETHStorage {
    uint256 private constant SSLOT = uint256(keccak256("lpeth.xyz.storage.location")) - 1;

    struct Data {
        LPToken lpToken;
        // total amount unlocking
        uint256 unlocking;
        // total amount of liabilities owed to LPs
        uint256 liabilities;
        // sum of token supplies that have outstanding unlocks
        UD60x18 S;
        // Recovery amount, if `recovery` > 0 enable recovery mode
        uint256 recovery;
        // treasury share of rewards pending withdrawal
        uint256 treasuryRewards;
        // Unlock queue to hold unlocks
        UnsETHQueue.Data unsETHQueue;
        // Withdraw request queue
        WithdrawQueue.Data withdrawQueue;
        // amount unlocking per asset
        mapping(address asset => uint256 unlocking) unlockingForAsset;
        // last supply of a tenderizer when seen, tracked because they are rebasing tokens
        mapping(address asset => UD60x18 lastSupply) lastSupplyForAsset;
        // relayer fees
        mapping(address relayer => uint256 reward) relayerRewards;
        // fee gauges
        mapping(address => UD60x18) gauges;
    }

    function _loadStorageSlot() internal pure returns (Data storage $) {
        uint256 slot = SSLOT;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := slot
        }
    }
}

contract LpETH is
    LpETHStorage,
    LpETHEvents,
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    Multicallable,
    SelfPermit,
    ERC721Receiver
{
    using UnsETHQueue for UnsETHQueue.Data;
    using WithdrawQueue for WithdrawQueue.Data;

    LPToken private immutable LPTOKEN = LPToken(address(0));
    Registry private immutable REGISTRY = Registry(address(0));
    UnsETH private immutable UNSETH = UnsETH(payable(0xA2FE2b9298c03AF9C5d885e62Bc04F77a7Ff91BF));
    address payable private immutable TREASURY = payable(0x5542b58080FEE48dBE6f38ec0135cE9011519d96);

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    receive() external payable { }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(ConstructorConfig memory config) {
        REGISTRY = config.registry;
        LPTOKEN = config.lpToken;
        UNSETH = config.unsETH;
        TREASURY = payable(config.treasury);
        _disableInitializers();
    }

    function setFeeGauge(address asset, UD60x18 gauge) external onlyOwner {
        Data storage $ = _loadStorageSlot();
        if (gauge.eq(ZERO_60x18)) revert GaugeZero();
        $.gauges[asset] = gauge;
    }

    function getFeeGauge(address asset) public view returns (UD60x18) {
        Data storage $ = _loadStorageSlot();
        UD60x18 gauge = $.gauges[asset];
        return gauge.eq(ZERO_60x18) ? UNIT_60x18 : gauge;
    }

    function deposit(uint256 minLpShares) external payable returns (uint256 lpShares) {
        Data storage $ = _loadStorageSlot();

        lpShares = $.liabilities > 0
            ? FixedPointMathLib.fullMulDiv(msg.value, LPTOKEN.totalSupply(), $.liabilities)
            : msg.value;

        if (lpShares < minLpShares) revert ErrorSlippage(lpShares, minLpShares);
        if (lpShares == 0) revert ErrorDepositSharesZero();

        LPTOKEN.mint(msg.sender, lpShares);
        $.liabilities += msg.value;

        emit Deposit(msg.sender, msg.value, lpShares);
    }

    function withdraw(uint256 amount, uint256 maxLpSharesBurnt) external returns (uint256 requestId) {
        Data storage $ = _loadStorageSlot();

        uint256 available = ud(amount).mul(UNIT_60x18.sub(ud($.unlocking).div(ud($.liabilities)))).unwrap();

        if (available < amount) {
            requestId = $.withdrawQueue.createRequest(uint128(amount - available), payable(msg.sender));
        }

        // Calculate LP tokens to burn
        uint256 lpShares =
            $.liabilities > 0 ? FixedPointMathLib.fullMulDivUp(amount, LPTOKEN.totalSupply(), $.liabilities) : amount;

        if (lpShares > maxLpSharesBurnt) revert ErrorSlippage(lpShares, maxLpSharesBurnt);

        // Update liabilities
        $.liabilities -= amount;

        // Burn LP tokens from the caller
        LPTOKEN.burn(msg.sender, lpShares);

        // Transfer available tokens to caller
        payable(msg.sender).transfer(available);

        emit Withdraw(msg.sender, amount, lpShares, requestId);
    }

    function quote(address asset, uint256 amount) external view returns (uint256 out) {
        Adapter adapter = REGISTRY.adapters(asset);
        if (address(adapter) == address(0)) revert ErrorInvalidAsset(asset);
        SwapParams memory p = _getSwapParams(asset, adapter);
        out = _quote(asset, amount, p);
    }

    function swap(address asset, uint256 amount, uint256 minOut) external returns (uint256 out) {
        Data storage $ = _loadStorageSlot();
        Adapter adapter = REGISTRY.adapters(asset);
        if (address(adapter) == address(0)) revert ErrorInvalidAsset(asset);
        SwapParams memory p = _getSwapParams(asset, adapter);

        SafeTransferLib.safeTransferFrom(asset, msg.sender, address(this), amount);
        SafeTransferLib.safeApprove(asset, address(UNSETH), amount);

        // Currently this method will revert if isn't between the MIN and MAX for the
        // specified 'asset'.
        // While we could handle this in the runtime in a future upgrade.
        // For now we'll handle this on the client side with 'multicall' and not being
        // able to swap less than the MIN.

        (uint256 tokenId, uint256 amountExpected) = UNSETH.requestWithdraw(asset, amount);

        (out) = _quote(asset, amountExpected, p);
        uint256 fee = amountExpected - out;

        // Revert if slippage threshold is exceeded, i.e. if `out` is less than `minOut`
        if (out < minOut) revert ErrorSlippage(out, minOut);

        // update pool state

        $.unsETHQueue.push(UnsETHQueue.Item({ tokenId: tokenId, fee: fee }));

        $.unlocking += amountExpected;
        $.unlockingForAsset[asset] += amountExpected;
        {
            UD60x18 x = ud(amountExpected);

            $.lastSupplyForAsset[asset] = p.s.sub(x);
            $.S = p.S.sub(x);
        }

        // Transfer `out` of `to` to msg.sender
        SafeTransferLib.safeTransferETH(msg.sender, out);

        emit Swap(msg.sender, asset, amount, fee, tokenId);
    }

    function redeemUnlock() external {
        Data storage $ = _loadStorageSlot();

        // get oldest item from unlock queue
        UnsETHQueue.Item memory unlock = $.unsETHQueue.popHead().data;

        if (!UNSETH.isFinalized(unlock.tokenId)) revert ErrorNotFinalized(unlock.tokenId);

        UnsETH.Request memory request = UNSETH.getRequest(unlock.tokenId);
        uint256 amountReceived = UNSETH.claimWithdraw(unlock.tokenId);

        uint256 fee = _doRecovery(amountReceived, request.amount, unlock.fee);

        // update pool state with liabilities
        {
            // - Update unlocking
            uint256 unlocked = _min(request.amount, amountReceived);
            $.unlocking -= unlocked;
            uint256 ufa = $.unlockingForAsset[request.derivative] - unlocked;
            // - Update S if unlockingForAsset is now zero
            if (ufa == 0) {
                $.S = $.S.sub($.lastSupplyForAsset[request.derivative]);
                $.lastSupplyForAsset[request.derivative] = ZERO_60x18;
            }
            // - Update unlockingForAsset
            $.unlockingForAsset[request.derivative] = ufa;
        }

        // account for rewards and fees
        //calculate the relayer reward
        uint256 relayerReward;
        uint256 lpReward;
        {
            relayerReward = ud(fee).mul(RELAYER_CUT).unwrap();
            // update relayer rewards
            $.relayerRewards[msg.sender] += relayerReward;

            // - Update liabilities to distribute LP rewards
            uint256 treasuryCut = ud(fee).mul(TREASURY_CUT).unwrap();
            $.treasuryRewards += treasuryCut;
            lpReward = fee - treasuryCut - relayerReward;
            $.liabilities += lpReward;
        }

        // Finalize requests
        {
            uint256 amountToFinalize = amountReceived - unlock.fee;
            $.withdrawQueue.finalizeRequests(amountToFinalize);
        }

        emit UnlockRedeemed(msg.sender, unlock.tokenId, amountReceived, relayerReward, lpReward);
    }

    function batchRedeemUnlocks(uint256 n) external {
        Data storage $ = _loadStorageSlot();
        uint256 totalReceived;
        uint256 totalExpected;
        uint256 totalFee;
        uint256[] memory tokenIds = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            // get oldest item from unlock queue
            UnsETHQueue.Item memory unlock = $.unsETHQueue.popHead().data;
            if (!UNSETH.isFinalized(unlock.tokenId)) break;

            UnsETH.Request memory request = UNSETH.getRequest(unlock.tokenId);
            uint256 amountReceived = UNSETH.claimWithdraw(unlock.tokenId);
            totalFee += unlock.fee;
            totalExpected += request.amount;
            totalReceived += amountReceived;

            uint256 ufa = $.unlockingForAsset[request.derivative] - _min(amountReceived, request.amount);
            // - Update S if unlockingForAsset is now zero
            if (ufa == 0) {
                $.S = $.S.sub($.lastSupplyForAsset[request.derivative]);
                $.lastSupplyForAsset[request.derivative] = ZERO_60x18;
            }
            // - Update unlockingForAsset
            $.unlockingForAsset[request.derivative] = ufa;
            tokenIds[i] = unlock.tokenId;
        }

        uint256 totalFeeAfterRecovery = _doRecovery(totalReceived, totalExpected, totalFee);
        // update pool state
        // - Update unlocking
        $.unlocking -= _min(totalExpected, totalReceived);

        //calculate the relayer reward
        uint256 relayerReward;
        uint256 lpReward;
        {
            relayerReward = ud(totalFeeAfterRecovery).mul(RELAYER_CUT).unwrap();
            // update relayer rewards
            $.relayerRewards[msg.sender] += relayerReward;

            // - Update liabilities to distribute LP rewards
            uint256 treasuryCut = ud(totalFeeAfterRecovery).mul(TREASURY_CUT).unwrap();
            $.treasuryRewards += treasuryCut;
            lpReward = totalFeeAfterRecovery - treasuryCut - relayerReward;
            $.liabilities += lpReward;
        }

        // Finalize requests
        {
            uint256 amountToFinalize = totalReceived - totalFee;
            $.withdrawQueue.finalizeRequests(amountToFinalize);
        }

        emit BatchUnlockRedeemed(msg.sender, totalReceived, relayerReward, lpReward, tokenIds);
    }

    function buyUnlock(uint256 expectedTokenId) external payable returns (uint256 tokenId) {
        Data storage $ = _loadStorageSlot();

        // Can not purchase unlocks in recovery mode
        // The fees need to flow back to paying off debt and relayers are cheaper
        if ($.recovery > 0) revert ErrorRecoveryMode();

        // get newest item from unlock queue
        UnsETHQueue.Item memory unlock = $.unsETHQueue.popTail().data;
        tokenId = unlock.tokenId;
        if (tokenId != expectedTokenId) revert UnexpectedTokenId();
        if (UNSETH.isFinalized(tokenId)) revert ErrorIsFinalized(tokenId);

        UnsETH.Request memory request = UNSETH.getRequest(tokenId);

        // Calculate the reward for purchasing the unlock
        // The base reward is the fee minus the MIN_LP_CUT going to liquidity providers and minus the TREASURY_CUT going
        // to the
        // treasury
        // The base reward then further decays as time to maturity decreases
        uint256 reward;
        uint256 lpCut;
        uint256 treasuryCut;
        {
            UD60x18 fee60x18 = ud(unlock.fee);
            lpCut = fee60x18.mul(MIN_LP_CUT).unwrap();
            treasuryCut = fee60x18.mul(TREASURY_CUT).unwrap();
            uint256 baseReward = unlock.fee - lpCut - treasuryCut;
            UD60x18 progress = ud(request.createdAt - block.timestamp).div(ud(UNSETH_EXPIRATION_TIME));
            reward = ud(baseReward).mul(UNIT_60x18.sub(progress)).unwrap();
            // Adjust lpCut by the remaining amount after subtracting the reward
            // This step seems to adjust lpCut to balance out the distribution
            // Assuming the final lpCut should encompass any unallocated fee portions
            lpCut += baseReward - reward;
        }

        // Update pool state
        // - update unlocking
        $.unlocking -= request.amount;
        // - Update liabilities to distribute LP rewards
        $.liabilities += lpCut;
        // - Update treasury rewards
        $.treasuryRewards += treasuryCut;

        uint256 ufa = $.unlockingForAsset[request.derivative] - request.amount;
        // - Update S if unlockingForAsset is now zero
        if (ufa == 0) {
            $.S = $.S.sub($.lastSupplyForAsset[request.derivative]);
            $.lastSupplyForAsset[request.derivative] = ZERO_60x18;
        }
        // - Update unlockingForAsset
        $.unlockingForAsset[request.derivative] = ufa;

        // Finalize requests
        {
            uint256 amountToFinalize = request.amount - unlock.fee;
            $.withdrawQueue.finalizeRequests(amountToFinalize);
        }

        // transfer unlock amount minus reward from caller to pool
        // the reward is the discount paid. 'reward < unlock.fee' always.
        if (msg.value < request.amount - reward) revert ErrorInsufficientAmount();

        // transfer unlock to caller
        UNSETH.safeTransferFrom(address(this), msg.sender, tokenId);
        // Transfer unused ETH back
        payable(msg.sender).transfer(msg.value - request.amount + reward);
        emit UnlockBought(msg.sender, tokenId, request.amount, reward, lpCut);
    }

    function batchBuyUnlock(uint256 n, uint256 expectedStartId) external payable {
        Data storage $ = _loadStorageSlot();

        // Can not purchase unlocks in recovery mode
        // The fees need to flow back to paying off debt and relayers are cheaper
        if ($.recovery > 0) revert ErrorRecoveryMode();

        uint256 totalAmountExpected;
        uint256 totalRewards;
        uint256 totalLpCut;
        uint256 totalTreasuryCut;
        uint256 msgValue = msg.value;

        uint256[] memory tokenIds = new uint256[](n);

        for (uint256 i = 0; i < n; i++) {
            // get newest item from unlock queue
            UnsETHQueue.Item memory unlock = $.unsETHQueue.popTail().data;
            if (i == 0 && unlock.tokenId != expectedStartId) revert UnexpectedTokenId();
            if (UNSETH.isFinalized(unlock.tokenId)) break;
            UnsETH.Request memory request = UNSETH.getRequest(unlock.tokenId);
            if (block.timestamp - request.createdAt > UNSETH_EXPIRATION_TIME) break;
            totalAmountExpected += request.amount;
            tokenIds[i] = unlock.tokenId;
            uint256 reward;
            {
                UD60x18 fee60x18 = ud(unlock.fee);
                uint256 lpCut = fee60x18.mul(MIN_LP_CUT).unwrap();
                uint256 treasuryCut = fee60x18.mul(TREASURY_CUT).unwrap();
                uint256 baseReward = unlock.fee - lpCut - treasuryCut;
                UD60x18 progress = ud(request.createdAt - block.timestamp).div(ud(UNSETH_EXPIRATION_TIME));
                reward = ud(baseReward).mul(UNIT_60x18.sub(progress)).unwrap();
                // Adjust lpCut by the remaining amount after subtracting the reward
                // This step seems to adjust lpCut to balance out the distribution
                // Assuming the final lpCut should encompass any unallocated fee portions
                lpCut += baseReward - reward;
                totalRewards += reward;
                totalLpCut += lpCut;
                totalTreasuryCut += treasuryCut;
            }

            uint256 ufa = $.unlockingForAsset[request.derivative] - request.amount;
            // - Update S if unlockingForAsset is now zero
            if (ufa == 0) {
                $.S = $.S.sub($.lastSupplyForAsset[request.derivative]);
                $.lastSupplyForAsset[request.derivative] = ZERO_60x18;
            }
            // - Update unlockingForAsset
            $.unlockingForAsset[request.derivative] = ufa;

            // transfer unlock amount minus reward from caller to pool
            // the reward is the discount paid. 'reward < unlock.fee' always.
            if (msgValue < request.amount - reward) revert ErrorInsufficientAmount();
            msgValue -= request.amount - reward;
            // transfer unlock to caller
            UNSETH.safeTransferFrom(address(this), msg.sender, unlock.tokenId);
        }

        // Update pool state
        // - update unlocking
        $.unlocking -= totalAmountExpected;
        // - Update liabilities to distribute LP rewards
        $.liabilities += totalLpCut;
        // - Update treasury rewards
        $.treasuryRewards += totalTreasuryCut;

        // Finalize requests
        {
            uint256 amountToFinalize = totalAmountExpected - totalRewards - totalLpCut - totalTreasuryCut;
            $.withdrawQueue.finalizeRequests(amountToFinalize);
        }

        // transfer unused ETH back
        if (msgValue > 0) {
            payable(msg.sender).transfer(msgValue);
        }

        emit BatchUnlockBought(msg.sender, totalAmountExpected, totalRewards, totalLpCut, tokenIds);
    }

    /**
     * @notice Claim outstanding rewards for a relayer.
     * @return relayerReward Amount of tokens claimed
     */
    function claimRelayerRewards() external returns (uint256 relayerReward) {
        Data storage $ = _loadStorageSlot();

        relayerReward = $.relayerRewards[msg.sender];

        delete $.relayerRewards[msg.sender];

        payable(msg.sender).transfer(relayerReward);

        emit RelayerRewardsClaimed(msg.sender, relayerReward);
    }

    function claimTreasuryRewards() external onlyOwner returns (uint256 treasuryReward) {
        Data storage $ = _loadStorageSlot();

        treasuryReward = $.treasuryRewards;

        $.treasuryRewards = 0;

        payable(TREASURY).transfer(treasuryReward);
    }

    function claimWithdrawRequest(uint256 id) external returns (uint256 amount) {
        amount = _loadStorageSlot().withdrawQueue.claimRequest(id);
        emit ClaimWithdrawRequest(id, msg.sender, amount);
    }

    function getWithdrawRequest(uint256 id) external view returns (WithdrawQueue.Request memory) {
        return _loadStorageSlot().withdrawQueue.getRequest(id);
    }

    function getClaimableForWithdrawRequest(uint256 id) external view returns (uint256) {
        return _loadStorageSlot().withdrawQueue.getClaimableForRequest(id);
    }

    function lpToken() external view returns (address) {
        return address(LPTOKEN);
    }

    function liabilities() external view returns (uint256) {
        Data storage $ = _loadStorageSlot();
        return $.liabilities;
    }

    /**
     * @notice Amount of available liquidity (cash on hand).
     */
    function liquidity() public view returns (uint256) {
        Data storage $ = _loadStorageSlot();
        return $.liabilities - $.unlocking;
    }

    /**
     * @notice Check outstanding rewards for a relayer.
     * @param relayer Address of the relayer
     * @return relayerReward Amount of tokens that can be claimed
     */
    function pendingRelayerRewards(address relayer) external view returns (uint256) {
        Data storage $ = _loadStorageSlot();
        return $.relayerRewards[relayer];
    }

    ///@dev required by the OZ UUPS module
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner { }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _getSwapParams(address asset, Adapter adapter) internal view returns (SwapParams memory p) {
        Data storage $ = _loadStorageSlot();

        UD60x18 U = ud($.unlocking);
        UD60x18 u = ud($.unlockingForAsset[asset]);
        (UD60x18 s, UD60x18 S) = _checkTotalETHStaked(asset, adapter);
        p = SwapParams({ U: U, u: u, S: S, s: s });
    }

    /**
     * @notice Since the LSTs to be exchanged are aTokens, and thus have a rebasing supply,
     * we need to update the supplies upon a swap to correctly determine the spread of the asset.
     */
    function _checkTotalETHStaked(address asset, Adapter adapter) internal view returns (UD60x18 s, UD60x18 S) {
        Data storage $ = _loadStorageSlot();

        S = $.S;

        s = ud(adapter.totalStaked());
        UD60x18 oldSupply = $.lastSupplyForAsset[asset];

        if (oldSupply.lt(s)) {
            S = S.add(s.sub(oldSupply));
        } else if (oldSupply.gt(s)) {
            S = S.sub(oldSupply.sub(s));
        }
    }

    function _quote(address asset, uint256 amount, SwapParams memory p) internal view returns (uint256 out) {
        Data storage $ = _loadStorageSlot();
        UD60x18 x = ud(amount);
        UD60x18 nom = _calculateNominator(x, p, $);
        UD60x18 denom = _calculateDenominator(p);

        UD60x18 gauge = getFeeGauge(asset);
        // total fee = gauge x (baseFee * amount + nom/denom)
        uint256 fee = BASE_FEE.mul(x).add(nom.div(denom)).mul(gauge).unwrap();
        fee = fee >= amount ? amount : fee;
        unchecked {
            out = amount - fee;
        }
    }

    function _calculateNominator(UD60x18 x, SwapParams memory p, Data storage $) internal view returns (UD60x18 nom) {
        UD60x18 L = ud($.liabilities);
        UD60x18 sumA = p.u.add(x).mul(K).add(p.u);
        UD60x18 negatorB = K.add(UNIT_60x18).mul(p.u);
        UD60x18 util = p.U.div(L).pow(K);
        UD60x18 util_change = p.U.add(x).div(L).pow(K);

        if (sumA < p.U) {
            sumA = p.U.sub(sumA).mul(util_change);
            // we must subtract sumA from sumB
            // we know sumB must always be positive so we
            // can proceed with the regular calculation
            UD60x18 sumB = p.U.sub(negatorB).mul(util);
            nom = sumB.sub(sumA).mul(p.S.add(p.U));
        } else {
            // sumA is positive, sumB can be positive or negative
            sumA = sumA.sub(p.U).mul(util_change);
            if (p.U < negatorB) {
                UD60x18 sumB = negatorB.sub(p.U).mul(util);
                nom = sumA.sub(sumB).mul(p.S.add(p.U));
            } else {
                UD60x18 sumB = p.U.sub(negatorB).mul(util);
                nom = sumA.add(sumB).mul(p.S.add(p.U));
            }
        }
    }

    function _calculateDenominator(SwapParams memory p) internal pure returns (UD60x18) {
        return K.mul(UNIT_60x18.add(K)).mul(p.s.add(p.u));
    }

    function _doRecovery(
        uint256 amountReceived,
        uint256 amountExpected,
        uint256 fee
    )
        internal
        returns (uint256 remaining)
    {
        Data storage $ = _loadStorageSlot();
        uint256 recovery = $.recovery;

        // Handle deficit
        if (amountReceived < amountExpected) {
            recovery += amountExpected - amountReceived;
        }

        // Handle surplus
        if (amountReceived > amountExpected) {
            uint256 excess = amountReceived - amountExpected;
            amountReceived = amountExpected;
            if (excess > recovery) {
                excess -= recovery;
                recovery = 0;
                $.liabilities += excess;
            } else {
                recovery -= excess;
                excess = 0;
            }
        }

        if (recovery > 0) {
            if (fee >= recovery) {
                unchecked {
                    fee -= recovery;
                    recovery = 0;
                }
            } else {
                unchecked {
                    recovery -= fee;
                    fee = 0;
                }
            }
        }
        remaining = fee;
        $.recovery = recovery;
    }
}
