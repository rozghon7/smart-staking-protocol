// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IActivityTracker {
    function setUserActivityBonusForStakedBalance(address _user, uint256 _score) external;
    function getUserActivityBonusForStakedBalance(address _user) external view returns (uint256);
    function setUserActivityBonusForTime(address _user, uint256 _score) external;
    function getUserActivityBonusForTime(address _user) external view returns(uint256 _score);
}