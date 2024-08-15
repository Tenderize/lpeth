pragma solidity ^0.8.25;

import { UD60x18, ud, UNIT as UNIT_60x18, ZERO as ZERO_60x18 } from "@prb/math/UD60x18.sol";
import { ERC20 } from "@solady/tokens/ERC20.sol";
import { WETH } from "@solady/tokens/WETH.sol";
import { SafeTransferLib } from "@solady/utils/SafeTransferLib.sol";

import { OwnableUpgradeable } from "@openzeppelin/upgradeable/access/OwnableUpgradeable.sol";
import { Initializable } from "@openzeppelin/upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { LpETH } from "@/lpETH/LPETH.sol";

address payable constant weth = payable(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));

interface VotingEscrow {
    function lockFor(address, uint256 amount, uint256 duration) external;
}

struct Lockup {
    uint256 amount;
    uint256 duration; // In epochs
}

struct Config {
    uint256 cap;
    uint256 deadline;
    uint256 minLockup;
    uint256 maxLockup;
    uint256 epochLength;
    UD60x18 maxMultiplier;
    UD60x18 slope;
}

error InvalidDuration();
error Inactive();
error NotClaimable();
error CapExceeded();

contract PreLaunch is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 public immutable cap; // Maximum amount of deposits allowed
    uint256 public immutable deadline; // Deadline for deposits
    UD60x18 internal immutable MIN_LOCKUP_DURATION;
    UD60x18 internal immutable MAX_LOCKUP_DURATION;
    UD60x18 internal immutable MAX_MULTIPLIER;
    UD60x18 internal immutable SLOPE;
    uint256 internal immutable EPOCH_LENGTH;

    uint256 totalWeightedDeposits; // Total weighted deposits
    uint256 totalDeposits; // Total deposits
    address public votingEscrow; // Voting escrow contract
    address payable lpEth; // LP token for lpETH
    uint96 claimableTimestamp; // Timestamp when deposits become claimable
    uint256 lpEthReceived = 0;

    mapping(address account => Lockup) internal lockups;

    constructor(Config memory _config) {
        cap = _config.cap;
        deadline = _config.deadline;
        MIN_LOCKUP_DURATION = UD60x18.wrap(_config.minLockup * 1e18);
        MAX_LOCKUP_DURATION = UD60x18.wrap(_config.maxLockup * 1e18);
        MAX_MULTIPLIER = _config.maxMultiplier;
        SLOPE = _config.slope;
        EPOCH_LENGTH = _config.epochLength;
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    receive() external payable { }

    function lockup(address account) external view returns (Lockup memory) {
        return lockups[account];
    }

    function isActive() public view returns (bool) {
        return block.timestamp <= deadline;
    }

    function isClaimable() public view returns (bool) {
        return votingEscrow != address(0);
    }

    function setLpEth(address payable _lpEth) external onlyOwner {
        if (lpEth != address(0)) {
            revert();
        }
        lpEth = _lpEth;
    }

    function setVotingEscrow(address _votingEscrow) external onlyOwner {
        if (votingEscrow != address(0)) {
            revert();
        }
        votingEscrow = _votingEscrow;
        claimableTimestamp = uint96(block.timestamp);
    }

    function mintLpEth(uint256 minLpShares) external onlyOwner {
        if (lpEth == address(0)) {
            revert();
        }

        if (isActive()) {
            revert();
        }

        uint256 lpShares = LpETH(lpEth).deposit{ value: address(this).balance }(minLpShares);
        lpEthReceived += lpShares;
    }

    function depositETH(uint256 duration) external payable {
        _deposit(msg.value, duration);
    }

    function depositWETH(uint256 amount, uint256 duration) external {
        SafeTransferLib.safeTransferFrom(weth, msg.sender, address(this), amount);
        SafeTransferLib.safeApprove(weth, weth, amount);
        WETH(weth).withdraw(amount);
        _deposit(amount, duration);
    }

    function _deposit(uint256 amount, uint256 duration) internal {
        if (!isActive()) {
            revert Inactive();
        }
        if (!isValidDuration(duration)) {
            revert InvalidDuration();
        }

        if (totalDeposits + amount > cap) {
            revert CapExceeded();
        }

        // Since we allow changing the lockup before the deadline
        // When a user has an existing deposit, and his new deposit has a different lockup,
        // We adopt the latest lockup set.
        // 1. Calculate existing weighted deposit
        // 2. Subtract the existing weighted deposit from the totalWeightedDeposits
        // 3. Add the new weighted deposit to the totalWeightedDeposits
        // 4. Update the lockup
        // 5. Update the totalDeposits

        Lockup storage lockup = lockups[msg.sender];
        if (lockup.amount > 0) {
            uint256 existingWeightedDeposit = calculateWeightedDeposit(lockup.amount, lockup.duration);
            unchecked {
                totalWeightedDeposits -= existingWeightedDeposit;
            }
        }

        uint256 weightedDeposit = calculateWeightedDeposit(amount + lockup.amount, duration);
        totalWeightedDeposits += weightedDeposit;
        totalDeposits += amount;

        lockups[msg.sender] = Lockup({ amount: amount + lockup.amount, duration: duration });
    }

    function withdraw(uint256 amount) external {
        if (!isActive()) {
            revert Inactive();
        }

        // 1. Calculate the weighted deposit
        // 2. Subtract the weighted deposit from the totalWeightedDeposits
        // 3. Calculate the weighted deposit based on the remaining balance
        // 4. Add the new weighted deposit to the totalWeightedDeposits
        // 5. Update the lockup
        // 6. Update the totalDeposits
        Lockup storage lockup = lockups[msg.sender];

        uint256 weightedDeposit = calculateWeightedDeposit(lockup.amount, lockup.duration);
        totalWeightedDeposits -= weightedDeposit;
        uint256 remainingAmount = lockup.amount - amount;
        uint256 remainingWeightedDeposit = calculateWeightedDeposit(remainingAmount, lockup.duration);
        totalWeightedDeposits += remainingWeightedDeposit;
        unchecked {
            totalDeposits -= amount;
        }
        lockup.amount = remainingAmount;

        payable(msg.sender).transfer(amount);
    }

    function changeLockup(uint256 duration) external {
        if (!isActive()) {
            revert Inactive();
        }
        if (!isValidDuration(duration)) {
            revert InvalidDuration();
        }

        Lockup storage lockup = lockups[msg.sender];

        uint256 weightedDeposit = calculateWeightedDeposit(lockup.amount, lockup.duration);
        totalWeightedDeposits -= weightedDeposit;
        uint256 newWeightedDeposit = calculateWeightedDeposit(lockup.amount, duration);
        totalWeightedDeposits += newWeightedDeposit;
        lockup.duration = duration;
    }

    function claimVeTokens() external {
        if (!isClaimable()) {
            revert NotClaimable();
        }
        Lockup storage lockup = lockups[msg.sender];
        // Account for elapsed time since the deposits became claimable in epochs
        uint256 epochsElapsedSinceClaimable = (block.timestamp - claimableTimestamp) / EPOCH_LENGTH;
        uint256 lpEthAmount = lockup.amount * lpEthReceived / totalDeposits;
        SafeTransferLib.safeApprove(lpEth, votingEscrow, lpEthAmount);
        if (lockup.duration > epochsElapsedSinceClaimable) {
            VotingEscrow(votingEscrow).lockFor(msg.sender, lpEthAmount, lockup.duration - epochsElapsedSinceClaimable);
        } else {
            ERC20(LpETH(lpEth).lpToken()).transfer(msg.sender, lpEthAmount);
        }
        delete lockups[msg.sender];
    }

    function calculateWeightedDeposit(uint256 amount, uint256 epochs) public view returns (uint256) {
        UD60x18 durationUD = UD60x18.wrap(epochs * 1e18);
        if (durationUD.lt(MIN_LOCKUP_DURATION)) {
            return 0;
        }
        return UD60x18.wrap(amount).mul(
            MAX_MULTIPLIER.mul(
                durationUD.sub(MIN_LOCKUP_DURATION).div(MAX_LOCKUP_DURATION - MIN_LOCKUP_DURATION).pow(SLOPE)
            )
        ).unwrap();
    }

    function isValidDuration(uint256 duration) internal view returns (bool) {
        // We compare the unscaled version of epochs so we increase stepwise per epoch
        // If we compare against the fixed point version, we can end up in between epochs
        return duration >= MIN_LOCKUP_DURATION.unwrap() / 1e18 && duration <= MAX_LOCKUP_DURATION.unwrap() / 1e18;
    }

    ///@dev required by the OZ UUPS module
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner { }
}
