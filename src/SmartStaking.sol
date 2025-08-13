//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Gas-effective Staking Contract.
/// @author rozghon7.
/// @notice Manages the staking of tokens and the distribution of rewards.
contract Staking is Ownable, ReentrancyGuard {
    /// @notice SafeERC20 is used to avoid reentrancy attacks.
    using SafeERC20 for IERC20;

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

    /// @notice Reverts if the token is a zero address.
    error TokenCantBeZeroAddress();
    /// @notice Reverts if the staking and reward tokens are the same.
    error StakingAndRewardTokensMustBeDifferent();
    /// @notice Reverts if the reward APR is zero.
    error RewardAPRMustBeGraterThenZero();
    /// @notice Reverts if the user does not have enough funds to stake.
    error NotEnoughtFunds();
    /// @notice Reverts if the amount to unstake is more than the staked balance.
    error AmountMoreThanStaked();
    /// @notice Reverts if the contract does not have enough funds to send rewards.
    error ContractHaveNotEnoughtFunds();
    /// @notice Reverts if the amount is zero.
    error AmountMustBeGraterThenZero();
    /// @notice Reverts if the tokens not approved by the user.
    error TokensNotApproved();
    /// @notice Reverts if the user does not have anything to unstake.
    error NothingToUnstake();
    /// @notice Reverts if the user does not have anything to claim.
    error NothingToClaim();
    /// @notice Reverts if the amount to deposit is zero.
    error DepositAmountMustBeGraterThenZero();

    /// @notice Emitted when a user stakes tokens.
    /// @param user The address of the user who staked the tokens.
    /// @param amount The amount of tokens that were staked.
    event NewStaking(address indexed user, uint256 indexed amount);
    /// @notice Emitted when a user unstakes tokens.
    /// @param user The address of the user who unstaked the tokens.
    /// @param amount The amount of tokens that were unstaked.
    event NewUnstaking(address indexed user, uint256 indexed amount);
    /// @notice Emitted when a user claims rewards.
    /// @param user The address of the user who claimed the rewards.
    /// @param amount The amount of tokens that were claimed.
    event RewardsClaimed(address indexed user, uint256 indexed amount);
    /// @notice Emitted when the APR is updated.
    /// @param newAPR The new APR.
    event APRUpdated(uint256 indexed newAPR);
    /// @notice Emitted when new reward tokens are deposited.
    /// @param amount The amount of tokens that were deposited.
    event NewRewardTokensFunding(uint256 indexed amount);

    /// @notice Mapping of user addresses to their staked balances.
    mapping(address => uint256) public stakedBalances;
    /// @notice Mapping of user addresses to their reward per token paid from last activity.
    mapping(address => uint256) public userRewardPerTokenPaid;
    /// @notice Mapping of user addresses to their available reward tokens to claim.
    mapping(address => uint256) public rewards;

    /// @notice Initializes the contract with the staking and reward tokens and the reward APR.
    /// @param _stakingToken The address of the staking token.
    /// @param _rewardToken The address of the reward token.
    /// @param _rewardAPR The reward APR.
    constructor(address _stakingToken, address _rewardToken, uint256 _rewardAPR) Ownable(msg.sender) {
        if (_stakingToken == address(0) || _rewardToken == address(0)) revert TokenCantBeZeroAddress();
        if (_stakingToken == _rewardToken) revert StakingAndRewardTokensMustBeDifferent();
        if (_rewardAPR == 0) revert RewardAPRMustBeGraterThenZero();

        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        rewardAPR = _rewardAPR;
        lastUpdateTime = block.timestamp;
    }

    /// @notice Internal function that updates the reward per token index.
    function updateRewardPerToken() internal {
        if (totalStaked == 0) {
            lastUpdateTime = block.timestamp;
            return;
        }

        uint256 passedTime = block.timestamp - lastUpdateTime;
        uint256 rewardPerTokenPerSec = (rewardAPR * PRECISION_FACTOR) / REWARD_APR_MULTIPLIER / SECONDS_PER_YEAR;

        rewardPerTokenIndexStored += (rewardPerTokenPerSec * passedTime);
        lastUpdateTime = block.timestamp;
    }

    /// @notice Internal function that updates the user's rewards.
    /// @param user The address of the user whose rewards are to be updated.
    function updateUserRewards(address user) internal {
        uint256 newRewards =
            (stakedBalances[user] * (rewardPerTokenIndexStored - userRewardPerTokenPaid[user])) / PRECISION_FACTOR;

        rewards[user] += newRewards;
        userRewardPerTokenPaid[user] = rewardPerTokenIndexStored;
    }

    /// @notice The function which shows available user rewards to claim.
    /// @param user The address of the user whose rewards are to be checked.
    /// @return The amount of rewards that the user can claim.
    function availableRewards(address user) external view returns (uint256) {
        uint256 currentRewardPerToken = rewardPerTokenIndexStored;

        if (stakedBalances[user] == 0) return rewards[user];

        uint256 passedTime = block.timestamp - lastUpdateTime;
        uint256 totalRewardToAdd = ((totalStaked * rewardAPR * passedTime) / REWARD_APR_MULTIPLIER) / SECONDS_PER_YEAR;
        currentRewardPerToken += (totalRewardToAdd * PRECISION_FACTOR) / totalStaked;

        uint256 newRewards =
            (stakedBalances[user] * (currentRewardPerToken - userRewardPerTokenPaid[user])) / PRECISION_FACTOR;

        return rewards[user] + newRewards;
    }

    /// @notice Allows a user to stake funds.
    /// @param amount The amount of tokens to stake.
    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountMustBeGraterThenZero();
        if (stakingToken.balanceOf(msg.sender) < amount) revert NotEnoughtFunds();
        if (stakingToken.allowance(msg.sender, address(this)) < amount) revert TokensNotApproved();

        updateRewardPerToken();
        updateUserRewards(msg.sender);

        stakedBalances[msg.sender] = stakedBalances[msg.sender] + amount;
        totalStaked = totalStaked + amount;

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit NewStaking(msg.sender, amount);
    }

    /// @notice Allows a user to unstake funds.
    /// @param amount The amount of tokens to unstake.
    function unstake(uint256 amount) external nonReentrant {
        if (stakedBalances[msg.sender] == 0) revert NothingToUnstake();
        if (amount == 0) revert AmountMustBeGraterThenZero();
        if (amount > stakedBalances[msg.sender]) revert AmountMoreThanStaked();

        updateRewardPerToken();
        updateUserRewards(msg.sender);

        totalStaked = totalStaked - amount;
        stakedBalances[msg.sender] = stakedBalances[msg.sender] - amount;

        stakingToken.safeTransfer(msg.sender, amount);

        emit NewUnstaking(msg.sender, amount);
    }

    /// @notice Allows a user to claim rewards.
    function claim() external nonReentrant {
        updateRewardPerToken();
        updateUserRewards(msg.sender);

        uint256 rewardsToClaim = rewards[msg.sender];

        if (rewardsToClaim == 0) revert NothingToClaim();
        if (rewardToken.balanceOf(address(this)) < rewardsToClaim) revert ContractHaveNotEnoughtFunds();

        rewards[msg.sender] = 0;

        rewardToken.safeTransfer(msg.sender, rewardsToClaim);

        emit RewardsClaimed(msg.sender, rewardsToClaim);
    }

    /// @notice Allows the owner to deposit reward tokens.
    /// @param amount The amount of tokens to deposit.
    function depositRewardTokens(uint256 amount) external onlyOwner {
        if (amount == 0) revert DepositAmountMustBeGraterThenZero();

        rewardToken.safeTransferFrom(msg.sender, address(this), amount);

        emit NewRewardTokensFunding(amount);
    }

    /// @notice Allows the owner to update the reward APR.
    /// @param newAPR The new reward APR.
    /// @dev The reward APR must be greater than zero.
    function updateAPR(uint256 newAPR) external onlyOwner {
        if (newAPR == 0) revert RewardAPRMustBeGraterThenZero();
        updateRewardPerToken();

        rewardAPR = newAPR;

        emit APRUpdated(newAPR);
    }
}
