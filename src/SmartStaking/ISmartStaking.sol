//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title Smart Staking Interface.
/// @author rozghon7.
/// @notice Interface for the Smart Staking contract, defining the functions and events.
interface ISmartStaking {
    /// @notice Emitted when a user stakes tokens.
    /// @param _user The address of the user who staked the tokens.
    /// @param _amount The amount of tokens that were staked.
    event NewStaking(address indexed _user, uint256 indexed _amount);
    /// @notice Emitted when a user unstakes tokens.
    /// @param _user The address of the user who unstaked the tokens.
    /// @param _amount The amount of tokens that were unstaked.
    event NewUnstaking(address indexed _user, uint256 indexed _amount);
    /// @notice Emitted when a user claims rewards.
    /// @param _user The address of the user who claimed the rewards.
    /// @param _amount The amount of tokens that were claimed.
    event RewardsClaimed(address indexed _user, uint256 indexed _amount);
    /// @notice Emitted when the APR is updated.
    /// @param _newAPR The new APR.
    event APRUpdated(uint256 indexed _newAPR);
    /// @notice Emitted when new reward tokens are deposited.
    /// @param _amount The amount of tokens that were deposited.
    event NewRewardTokensFunding(uint256 indexed _amount);

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
    /// @notice Reverts if the activity tracker contract address is zero.
    error ActivityTrackerContractCantBeZeroAddress();
    /// @notice Reverts if the caller is not the staker.
    error CallerIsNotStaker();

    /// @notice The function which shows available user rewards to claim.
    /// @param _user The address of the user whose rewards are to be checked.
    /// @return The amount of rewards that the user can claim.
    function availableRewards(address _user) external view returns (uint256);
    /// @notice Allows a user to stake funds.
    /// @param _amount The amount of tokens to stake.
    function stake(uint256 _amount) external;
    /// @notice Allows a user to unstake funds.
    /// @param _amount The amount of tokens to unstake.
    function unstake(uint256 _amount) external;
    /// @notice Allows a user to claim rewards for staking.
    function claim() external;
    /// @notice Allows the owner to deposit reward tokens.
    /// @param _amount The amount of tokens to deposit.
    function depositRewardTokens(uint256 _amount) external;
    /// @notice Allows the owner to update the reward APR.
    /// @param _newAPR The new reward APR.
    /// @dev The reward APR must be greater than zero.
    function updateAPR(uint256 _newAPR) external;
    /// @notice Updates the user's points for time with protocol.
    /// @dev This function calculates the user's activity bonus based on the time they are interacting with the protocol.
    function updateUserPointsForTimeWithProtocol() external;
}
