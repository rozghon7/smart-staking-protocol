//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IActivityTracker} from "../ActivityTracker/IActivityTracker.sol";
import {ISmartStaking} from "../SmartStaking/ISmartStaking.sol";
import {LibrarySmartStaking} from "../SmartStaking/LibrarySmartStaking.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title Gas-effective Staking Contract with a bonus system.
/// @author rozghon7.
/// @notice Manages the staking of tokens and the distribution of rewards.
contract Staking is ISmartStaking, ReentrancyGuard, Pausable, Ownable {
    /// @notice SafeERC20 is used to avoid reentrancy attacks.
    using SafeERC20 for IERC20;

    /// @notice Activity tracker contract to manage user activity scores.
    IActivityTracker public activityTrackerContract;

    /// @notice Tokens that are being staked.
    IERC20 public stakingToken;
    /// @notice Tokens that are being distributed as rewards.
    IERC20 public rewardToken;

    /// @notice Total amount of tokens that are being staked.
    uint256 public totalStaked;
    /// @notice Reward per token index stored.
    uint256 public rewardPerTokenIndexStored;
    /// @notice Last time the reward per token was updated.
    uint256 public lastUpdateTime;
    /// @notice Reward APR.
    uint256 public rewardAPR;

    /// @notice Precision factor.
    uint256 public constant PRECISION_FACTOR = 1e18;
    /// @notice Reward APR multiplier.
    uint256 public constant REWARD_APR_MULTIPLIER = 10000;
    /// @notice Seconds per year.
    uint256 public constant SECONDS_PER_YEAR = 31536000;

    /// @notice Maximum points bonus for time with protocol.
    uint256 public constant MAX_TIME_POINTS = 1000;
    /// @notice Maximum points bonus for staked balance.
    uint256 public constant MAX_BAL_POINTS = 2000;

    /// @notice Maximum bonus in basis points (BPS) for time with protocol.
    uint256 public constant MAX_TIME_BONUS_BPS = 200; // +2.00%
    /// @notice Maximum bonus in basis points (BPS) for staked balance.
    uint256 public constant MAX_BAL_BONUS_BPS = 300; // +3.00%
    /// @notice Maximum total bonus in basis points (BPS).
    uint256 public constant MAX_TOTAL_BONUS_BPS = 500; // +5.00%

    /// @notice Mapping of user addresses to their staked balances.
    mapping(address => uint256) public stakedBalances;
    /// @notice Mapping of user addresses to their reward per token paid from last activity.
    mapping(address => uint256) public userRewardPerTokenPaid;
    /// @notice Mapping of user addresses to their available reward tokens to claim.
    mapping(address => uint256) public rewards;
    /// @notice Mapping of user addresses to their timestamp for time bonus counting.
    mapping(address => uint256) public timestampForTimeBonusCouting;
    /// @notice Mapping of user addresses to their last bonus accrual update timestamp.
    mapping(address => uint256) public lastBonusAccrualUpdate;

    /// @notice Initializes the contract with the staking and reward tokens and the reward APR.
    /// @param _stakingToken The address of the staking token.
    /// @param _rewardToken The address of the reward token.
    /// @param _rewardAPR The reward APR.
    constructor(address _stakingToken, address _rewardToken, uint256 _rewardAPR, address _activityTrackerContract)
        payable
        Ownable(msg.sender)
    {
        if (_activityTrackerContract == address(0)) revert ActivityTrackerContractCantBeZeroAddress();
        if (_stakingToken == address(0) || _rewardToken == address(0)) revert TokenCantBeZeroAddress();
        if (_stakingToken == _rewardToken) revert StakingAndRewardTokensMustBeDifferent();
        if (_rewardAPR == 0) revert RewardAPRMustBeGraterThenZero();

        uint8 stakingDecimals = IERC20Metadata(_stakingToken).decimals();
        uint8 rewardDecimals = IERC20Metadata(_rewardToken).decimals();

        if (stakingDecimals != rewardDecimals) revert StakingAndRewardTokensCantHaveDifferentDecimals();

        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        activityTrackerContract = IActivityTracker(_activityTrackerContract);
        rewardAPR = _rewardAPR;
        lastUpdateTime = block.timestamp;
    }

    /// USERS FUNCTIONS

    /// @inheritdoc ISmartStaking
    function stake(uint256 _amount) external override nonReentrant whenNotPaused {
        if (_amount == 0) revert AmountMustBeGraterThenZero();
        if (stakingToken.balanceOf(msg.sender) < _amount) revert NotEnoughtFunds();
        if (stakingToken.allowance(msg.sender, address(this)) < _amount) revert TokensNotApproved();

        updateRewardPerToken();
        updateUserRewards(msg.sender);
        applyBonusRewardsForUser(msg.sender);

        stakedBalances[msg.sender] = stakedBalances[msg.sender] + _amount;
        totalStaked = totalStaked + _amount;

        if (timestampForTimeBonusCouting[msg.sender] == 0) {
            timestampForTimeBonusCouting[msg.sender] = block.timestamp;
        }

        updateGeneralUserBonusPointsWithStaking(msg.sender);

        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit NewStaking(msg.sender, _amount);
    }

    /// @inheritdoc ISmartStaking
    function unstake(uint256 _amount) external override nonReentrant whenNotPaused {
        if (stakedBalances[msg.sender] == 0) revert NothingToUnstake();
        if (_amount == 0) revert AmountMustBeGraterThenZero();
        if (_amount > stakedBalances[msg.sender]) revert AmountMoreThanStaked();

        updateRewardPerToken();
        updateUserRewards(msg.sender);
        applyBonusRewardsForUser(msg.sender);

        totalStaked = totalStaked - _amount;
        stakedBalances[msg.sender] = stakedBalances[msg.sender] - _amount;

        if (stakedBalances[msg.sender] == 0) {
            timestampForTimeBonusCouting[msg.sender] = 0;
        }

        updateGeneralUserBonusPointsWithUnstaking(msg.sender);

        stakingToken.safeTransfer(msg.sender, _amount);

        emit NewUnstaking(msg.sender, _amount);
    }

    /// @inheritdoc ISmartStaking
    function availableRewards(address _user) external view override returns (uint256) {
        uint256 currentRewardPerToken = rewardPerTokenIndexStored;

        if (stakedBalances[_user] == 0) {
            return rewards[_user];
        }

        uint256 passedTime = block.timestamp - lastUpdateTime;
        uint256 totalRewardToAdd = ((totalStaked * rewardAPR * passedTime) / REWARD_APR_MULTIPLIER) / SECONDS_PER_YEAR;
        currentRewardPerToken += (totalRewardToAdd * PRECISION_FACTOR) / totalStaked;

        uint256 newBaseRewards =
            (stakedBalances[_user] * (currentRewardPerToken - userRewardPerTokenPaid[_user])) / PRECISION_FACTOR;

        uint256 bonusBps = countingUserBonusPointsToAPR(_user);

        uint256 last = lastBonusAccrualUpdate[_user];
        uint256 timeForCounting = (last == 0) ? 0 : (block.timestamp - last);

        uint256 pendingBonus =
            (stakedBalances[_user] * bonusBps * timeForCounting) / REWARD_APR_MULTIPLIER / SECONDS_PER_YEAR;

        return rewards[_user] + newBaseRewards + pendingBonus;
    }

    /// @inheritdoc ISmartStaking
    function updateUserPointsForTimeWithProtocol() external override {
        applyBonusRewardsForUser(msg.sender);

        uint256 lastTime = timestampForTimeBonusCouting[msg.sender];
        uint256 blocktimestamp = block.timestamp;

        if (lastTime == 0) revert CallerIsNotStaker();

        if (blocktimestamp - lastTime < 2_628_000) {
            activityTrackerContract.setUserActivityBonusForTime(msg.sender, 0);
        } else if (blocktimestamp - lastTime < 15_768_000) {
            activityTrackerContract.setUserActivityBonusForTime(msg.sender, 50);
        } else if (blocktimestamp - lastTime < 31_536_000) {
            activityTrackerContract.setUserActivityBonusForTime(msg.sender, 250);
        } else if (blocktimestamp - lastTime < 63_072_000) {
            activityTrackerContract.setUserActivityBonusForTime(msg.sender, 500);
        } else if (blocktimestamp - lastTime < 94_608_000) {
            activityTrackerContract.setUserActivityBonusForTime(msg.sender, 750);
        } else {
            activityTrackerContract.setUserActivityBonusForTime(msg.sender, 1000);
        }
    }

    /// @inheritdoc ISmartStaking
    function claim() external override nonReentrant whenNotPaused {
        updateRewardPerToken();
        updateUserRewards(msg.sender);
        applyBonusRewardsForUser(msg.sender);

        uint256 rewardsToClaim = rewards[msg.sender];

        if (rewardsToClaim == 0) revert NothingToClaim();
        if (rewardToken.balanceOf(address(this)) < rewardsToClaim) revert ContractHaveNotEnoughtFunds();

        rewards[msg.sender] = 0;

        rewardToken.safeTransfer(msg.sender, rewardsToClaim);

        emit RewardsClaimed(msg.sender, rewardsToClaim);
    }

    /// OWNER/MODERATORS's FUNCTIONS

    /// @inheritdoc ISmartStaking
    function depositRewardTokens(uint256 _amount) external override onlyOwner {
        if (_amount == 0) revert DepositAmountMustBeGraterThenZero();

        rewardToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit NewRewardTokensFunding(_amount);
    }

    /// @inheritdoc ISmartStaking
    function updateAPR(uint256 _newAPR) external override onlyOwner {
        if (_newAPR == 0) revert RewardAPRMustBeGraterThenZero();
        updateRewardPerToken();

        rewardAPR = _newAPR;

        emit APRUpdated(_newAPR);
    }

    /// @notice Pauses the contract, preventing staking, unstaking, and claiming.
    /// @dev Only the owner can call this function.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract, allowing staking, unstaking, and claiming.
    /// @dev Only the owner can call this function.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// INTERNAL FUNCTIONS

    /// @notice Internal function that updates the reward per token index.
    /// @dev Implemetation of this function is in LibrarySmartStaking.
    function updateRewardPerToken() internal {
        (rewardPerTokenIndexStored, lastUpdateTime) = LibrarySmartStaking.calcRewardPerTokenIndex(
            totalStaked,
            lastUpdateTime,
            rewardPerTokenIndexStored,
            rewardAPR,
            PRECISION_FACTOR,
            REWARD_APR_MULTIPLIER,
            SECONDS_PER_YEAR,
            block.timestamp
        );
    }

    /// @notice Internal function that updates the user's rewards.
    /// @param _user The address of the user whose rewards are to be updated.
    function updateUserRewards(address _user) internal {
        uint256 newRewards =
            (stakedBalances[_user] * (rewardPerTokenIndexStored - userRewardPerTokenPaid[_user])) / PRECISION_FACTOR;

        rewards[_user] += newRewards;
        userRewardPerTokenPaid[_user] = rewardPerTokenIndexStored;
    }

    /// @notice Internal function that updates the general user bonus points for staked balance.
    /// @param _user The address of the user whose bonus points are to be updated.
    function updateGeneralUserBonusPointsWithStaking(address _user) internal {
        if (stakedBalances[_user] < 5000) {
            activityTrackerContract.setUserActivityBonusForStakedBalance(_user, 0);
        } else if (stakedBalances[_user] < 10000) {
            activityTrackerContract.setUserActivityBonusForStakedBalance(_user, 100);
        } else if (stakedBalances[_user] < 20000) {
            activityTrackerContract.setUserActivityBonusForStakedBalance(_user, 250);
        } else if (stakedBalances[_user] < 50000) {
            activityTrackerContract.setUserActivityBonusForStakedBalance(_user, 500);
        } else if (stakedBalances[_user] < 100000) {
            activityTrackerContract.setUserActivityBonusForStakedBalance(_user, 1000);
        } else {
            activityTrackerContract.setUserActivityBonusForStakedBalance(_user, 2000);
        }
    }

    /// @notice Internal function that updates the general user bonus points after unstaking.
    /// @param _user The address of the user whose bonus points are to be updated.
    function updateGeneralUserBonusPointsWithUnstaking(address _user) internal {
        if (stakedBalances[_user] < 5000) {
            activityTrackerContract.setUserActivityBonusForStakedBalance(_user, 0);
        } else if (stakedBalances[_user] < 10000) {
            activityTrackerContract.setUserActivityBonusForStakedBalance(_user, 100);
        } else if (stakedBalances[_user] < 20000) {
            activityTrackerContract.setUserActivityBonusForStakedBalance(_user, 250);
        } else if (stakedBalances[_user] < 50000) {
            activityTrackerContract.setUserActivityBonusForStakedBalance(_user, 500);
        } else if (stakedBalances[_user] < 100000) {
            activityTrackerContract.setUserActivityBonusForStakedBalance(_user, 1000);
        } else {
            activityTrackerContract.setUserActivityBonusForStakedBalance(_user, 2000);
        }
    }

    /// @notice Internal function that counts user bonus points to APR.
    /// @param _user The address of the user whose bonus points are to be counted.
    /// @return The total bonus points in basis points (BPS) that will be applied to the user's APR.
    /// @dev Implementation contains in LibrarySmartStaking.
    function countingUserBonusPointsToAPR(address _user) internal view returns (uint256) {
        return LibrarySmartStaking.calcBonusBps(
            activityTrackerContract.getUserActivityBonusForTime(_user),
            activityTrackerContract.getUserActivityBonusForStakedBalance(_user),
            MAX_TIME_POINTS,
            MAX_BAL_POINTS,
            MAX_TIME_BONUS_BPS,
            MAX_BAL_BONUS_BPS,
            MAX_TOTAL_BONUS_BPS
        );
    }

    /// @notice Internal function that applies bonus rewards for a user.
    /// @param _user The address of the user whose bonus rewards are to be applied.
    function applyBonusRewardsForUser(address _user) internal {
        uint256 last = lastBonusAccrualUpdate[_user];
        uint256 bal = stakedBalances[_user];
        uint256 blocktimestamp = block.timestamp;

        if (bal == 0) {
            lastBonusAccrualUpdate[_user] = blocktimestamp;
            return;
        }

        if (last == 0) {
            lastBonusAccrualUpdate[_user] = blocktimestamp;
            return;
        }

        uint256 timeForCounting = blocktimestamp - last;
        if (timeForCounting == 0) return;

        uint256 bonusBps = countingUserBonusPointsToAPR(_user);
        if (bonusBps == 0) {
            lastBonusAccrualUpdate[_user] = blocktimestamp;
            return;
        }

        uint256 bonus = (bal * bonusBps * timeForCounting) / REWARD_APR_MULTIPLIER / SECONDS_PER_YEAR;

        rewards[_user] += bonus;
        lastBonusAccrualUpdate[_user] = blocktimestamp;
    }
}
