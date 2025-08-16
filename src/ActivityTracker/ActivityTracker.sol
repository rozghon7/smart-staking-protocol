//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IActivityTracker} from "../ActivityTracker/IActivityTracker.sol";

/// @title Activity Tracker
/// @author rozghon7
/// @notice A contract to track and manage user activity scores for bonus rewards.
contract ActivityTracker is IActivityTracker, Ownable {
    /// @notice The address of the staking contract that can call certain functions.
    /// @dev This address is set by the owner and can only be changed by the owner.
    address public stakingContract;

    /// @notice Constructor to set the owner of the contract.
    constructor() payable Ownable(msg.sender) {}

    /// @notice Required modifier to restrict access to functions that can only be called by the staking contract.
    /// @dev This modifier checks if the caller is the staking contract.
    modifier onlyStakingContract() {
        if (msg.sender != stakingContract) revert OnlyStakingContractAllowedToCallFunction();
        _;
    }

    /// @notice Mapping to store user activity score for staked balance.
    mapping(address => uint256) usersBonusForBalancePoints;
    /// @notice Mapping to store user activity score for time with protocol.
    mapping(address => uint256) userBonusForTimePoints;

    /// @inheritdoc IActivityTracker
    function setStakingContract(address _stakingContract) external onlyOwner {
        if (_stakingContract == address(0)) revert StakingContractAddressCantBeZero();

        stakingContract = _stakingContract;
    }

    /// @inheritdoc IActivityTracker
    function setUserActivityBonusForStakedBalance(address _user, uint256 _score) external onlyStakingContract {
        uint256 lastActivityScore = usersBonusForBalancePoints[_user];
        usersBonusForBalancePoints[_user] = _score;

        emit UserActivityBonusForStakedBalanceUpdated(
            msg.sender, usersBonusForBalancePoints[_user], lastActivityScore, block.timestamp
        );
    }

    /// @inheritdoc IActivityTracker
    function getUserActivityBonusForStakedBalance(address _user) external view returns (uint256 _score) {
        return usersBonusForBalancePoints[_user];
    }

    /// @inheritdoc IActivityTracker
    function setUserActivityBonusForTime(address _user, uint256 _score) external onlyStakingContract {
        uint256 lastActivityScore = userBonusForTimePoints[_user];
        userBonusForTimePoints[_user] = _score;

        emit UserActivityBonusForTimeUpdated(
            msg.sender, userBonusForTimePoints[_user], lastActivityScore, block.timestamp
        );
    }

    /// @inheritdoc IActivityTracker
    function getUserActivityBonusForTime(address _user) external view returns (uint256 _score) {
        return userBonusForTimePoints[_user];
    }
}
