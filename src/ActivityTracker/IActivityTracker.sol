//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title Activity Tracker Interface.
/// @author rozghon7.
/// @notice Interface for the Activity Tracker contract, defining the functions and events.
interface IActivityTracker {
    /// @notice Emitted when a user's activity bonus for staked balance is updated.
    /// @param _user The address of the user whose activity bonus was updated.
    /// @param _relevantScore The new activity score for the user.
    /// @param _scoreBeforeIncremet The previous activity score before the update.
    /// @param _timestamp The timestamp when the activity bonus was updated.
    event UserActivityBonusForStakedBalanceUpdated(
        address indexed _user, uint256 indexed _relevantScore, uint256 _scoreBeforeIncremet, uint256 _timestamp
    );
    /// @notice Emitted when a user's activity bonus for time is updated.
    /// @param _user The address of the user whose activity bonus was updated.
    /// @param _relevantScore The new activity score for the user.
    /// @param _scoreBeforeIncremet The previous activity score before the update.
    /// @param _timestamp The timestamp when the activity bonus was updated.
    event UserActivityBonusForTimeUpdated(
        address indexed _user, uint256 indexed _relevantScore, uint256 _scoreBeforeIncremet, uint256 _timestamp
    );
    /// @notice Emitted when the staking contract address is set.
    /// @param _stakingContract The address of the staking contract that was set.
    event StakingContractSetted(address indexed _stakingContract);

    /// @notice Reverts if the caller is not the staking contract.
    error OnlyStakingContractAllowedToCallFunction();
    /// @notice Reverts if the staking contract address is zero.
    error StakingContractAddressCantBeZero();

    /// @notice Allows the owner to set the staking contract address.
    /// @param _stakingContract The address of the staking contract to be set.
    function setStakingContract(address _stakingContract) external;
    /// @notice Allows staking contract to set the activity bonus for a user based on their staked balance.
    /// @param _user The address of the user whose activity bonus is being set.
    /// @param _score The new activity score for the user.
    function setUserActivityBonusForStakedBalance(address _user, uint256 _score) external;
    /// @notice Shows the activity bonus for a user's staked balance.
    /// @param _user The address of the user whose activity bonus is being queried.
    /// @return _score The activity score for the user's staked balance.
    function getUserActivityBonusForStakedBalance(address _user) external view returns (uint256);
    /// @notice Allows staking contract to set the activity bonus for a user based on their time with protocol.
    /// @param _user The address of the user whose activity bonus is being set.
    /// @param _score The new activity score for the user.
    function setUserActivityBonusForTime(address _user, uint256 _score) external;
    /// @notice Shows the activity bonus for a user's time with protocol.
    /// @param _user The address of the user whose activity bonus is being queried.
    /// @return _score The activity score for the user's time with protocol.
    function getUserActivityBonusForTime(address _user) external view returns (uint256 _score);
}
