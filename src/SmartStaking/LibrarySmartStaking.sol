//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ISmartStaking} from "../SmartStaking/ISmartStaking.sol";

/// @title Library for Smart Staking calculations.
/// @author rozghon7.
/// @notice Contains utility functions for calculating reward per token index and bonus BPS in the Smart Staking contract.
/// @dev This library is used to implement the logic for calculating rewards and bonuses.
library LibrarySmartStaking {
    /// @notice Calculates the reward per token index.
    /// @param _totStaked The total amount of tokens currently staked.
    /// @param _lastUpdTime The last time the reward per token index was updated.
    /// @param _rewardPerTokIndStor The stored reward per token index.
    /// @param _rewardAPR The annual percentage rate (APR) for rewards.
    /// @param _PRECIS_FACTOR The precision factor used for calculations.
    /// @param _REWARD_APR_MULTIP The multiplier for the reward APR.
    /// @param _SECONDS_PER_YEAR The number of seconds in a year.
    /// @param _currTimestamp The current timestamp.
    /// @return newIndex The updated reward per token index.
    /// @return newLastUpdateTime The updated last update time.
    function calcRewardPerTokenIndex(
        uint256 _totStaked,
        uint256 _lastUpdTime,
        uint256 _rewardPerTokIndStor,
        uint256 _rewardAPR,
        uint256 _PRECIS_FACTOR,
        uint256 _REWARD_APR_MULTIP,
        uint256 _SECONDS_PER_YEAR,
        uint256 _currTimestamp
    ) internal pure returns (uint256 newIndex, uint256 newLastUpdateTime) {
        if (_totStaked == 0) {
            return (_rewardPerTokIndStor, _currTimestamp);
        }
        uint256 passedTime = _currTimestamp - _lastUpdTime;
        uint256 rewardPerTokenPerSec = (_rewardAPR * _PRECIS_FACTOR) / _REWARD_APR_MULTIP / _SECONDS_PER_YEAR;

        newIndex = _rewardPerTokIndStor + (rewardPerTokenPerSec * passedTime);
        newLastUpdateTime = _currTimestamp;
    }

    /// @notice Calculates the user bonus points in basis points (BPS).
    /// @param _pointsForTime The user's activity bonus points for time with protocol.
    /// @param _pointsForBalance The user's activity bonus points for staked balance.
    /// @param _MAX_TIME_POINTS The maximum points for time.
    /// @param _MAX_BAL_POINTS The maximum points for balance.
    /// @param _MAX_TIME_BONUS_BPS The maximum bonus BPS for time.
    /// @param _MAX_BAL_BONUS_BPS The maximum bonus BPS for balance.
    /// @param _MAX_TOTAL_BONUS_BPS The maximum total bonus BPS.
    /// @return The total bonus points in basis points (BPS) that will be applied to the user's APR.
    function calcBonusBps(
        uint256 _pointsForTime,
        uint256 _pointsForBalance,
        uint256 _MAX_TIME_POINTS,
        uint256 _MAX_BAL_POINTS,
        uint256 _MAX_TIME_BONUS_BPS,
        uint256 _MAX_BAL_BONUS_BPS,
        uint256 _MAX_TOTAL_BONUS_BPS
    ) internal pure returns (uint256) {
        uint256 balBps = (_pointsForBalance * _MAX_BAL_BONUS_BPS) / _MAX_BAL_POINTS;
        uint256 timeBps = (_pointsForTime * _MAX_TIME_BONUS_BPS) / _MAX_TIME_POINTS;
        uint256 total = balBps + timeBps;
        if (total > _MAX_TOTAL_BONUS_BPS) return _MAX_TOTAL_BONUS_BPS;
        return total;
    }
}
