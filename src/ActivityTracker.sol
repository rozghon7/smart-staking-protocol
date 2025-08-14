//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../src/IActivityTracker.sol";

/// @title Activity Tracker
/// @author rozghon7
/// @notice A contract to track and manage user activity scores for bonus rewards.
contract ActivityTracker is IActivityTracker, Ownable {
    address public stakingContract;
    constructor() Ownable(msg.sender) {
    }

    modifier onlyStakingContract() {
        if (msg.sender != stakingContract) revert OnlyStakingContractAllowedToCallFunction();
        _;
    }

    error ScoreAmountToAddMustBeGraterThenZero();
    error UserDoesntHaveAnyStakedFundsInProtocol();
    error OnlyStakingContractAllowedToCallFunction();
    error StakingContractAddressCantBeZero();

    event UserActivityBonusForStakedBalanceUpdated(uint256 indexed _relevantScore, uint256 _scoreBeforeIncremet, uint256 _timestamp);
    event UserActivityBonusForTimeUpdated(uint256 indexed _relevantScore, uint256 _scoreBeforeIncremet, uint256 _timestamp);

    mapping(address => uint256) usersBonusForBalancePoints;
    mapping(address => uint256) userBonusForTimePoints;

    function setStakingContract(address _stakingContract) external onlyOwner {
        if (_stakingContract == address(0)) revert StakingContractAddressCantBeZero();

        stakingContract = _stakingContract;
    }

    function setUserActivityBonusForStakedBalance(address _user, uint256 _score) external onlyStakingContract {


        uint256 lastActivityScore = usersBonusForBalancePoints[_user];
        usersBonusForBalancePoints[_user] = _score;

        emit UserActivityBonusForStakedBalanceUpdated(usersBonusForBalancePoints[_user], lastActivityScore, block.timestamp);
    }

    function getUserActivityBonusForStakedBalance(address _user) external view returns(uint256 _score) {
        return usersBonusForBalancePoints[_user];
    }

    function setUserActivityBonusForTime(address _user, uint256 _score) external onlyStakingContract {


        uint256 lastActivityScore = userBonusForTimePoints[_user];
        userBonusForTimePoints[_user] = _score;

        emit UserActivityBonusForTimeUpdated(userBonusForTimePoints[_user], lastActivityScore, block.timestamp);
    }

    function getUserActivityBonusForTime(address _user) external view returns(uint256 _score) {
        return userBonusForTimePoints[_user];
    }
}