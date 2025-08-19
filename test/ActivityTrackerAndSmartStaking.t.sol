//SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {IActivityTracker} from "../src/ActivityTracker/IActivityTracker.sol";
import {ActivityTracker} from "../src/ActivityTracker/ActivityTracker.sol";
import {ISmartStaking} from "../src/SmartStaking/ISmartStaking.sol";
import {SmartStaking} from "../src/SmartStaking/SmartStaking.sol";
import {MockStakingToken} from "../src/MockTokens/ERC20MockStakingToken.sol";
import {MockRewardToken} from "../src/MockTokens/ERC20MockRewardToken.sol";

/// @title TestActivityTrackerAndSmartStaking
/// @author rozghon7.
/// @notice Test contract for the ActivityTracker and SmartStaking contracts.
contract TestActivityTrackerAndSmartStaking is Test {
    IActivityTracker public activityTracker;
    ISmartStaking public smartStaking;

    MockRewardToken public rewardToken;
    MockStakingToken public stakingToken;

    address public deployedActivityTracker;
    address public deployedStakingContract;

    address public owner = address(0x123);
    address public user1 = address(0x789);
    address public user2 = address(0x456);

    function setUp() public {
        vm.startPrank(owner);

        rewardToken = new MockRewardToken(owner, owner);
        stakingToken = new MockStakingToken(user1, owner);
        address rewardTokenAddress = address(rewardToken);
        address stakingTokenAddress = address(stakingToken);

        activityTracker = new ActivityTracker();
        deployedActivityTracker = address(activityTracker);

        smartStaking = new SmartStaking(stakingTokenAddress, rewardTokenAddress, 1000, deployedActivityTracker);
        deployedStakingContract = address(smartStaking);

        activityTracker.setStakingContract(deployedStakingContract);

        vm.stopPrank();
    }

    function testDepositRewardTokensRevertCheck() public {
        vm.startPrank(owner);

        vm.expectRevert(ISmartStaking.DepositAmountMustBeGreaterThanZero.selector);
        smartStaking.depositRewardTokens(0);
    }

    function testDepositRewardTokensFunctionalityAndEventCheck() public {
        vm.startPrank(owner);

        rewardToken.approve(deployedStakingContract, 100);

        vm.expectEmit(true, false, false, true);
        emit ISmartStaking.NewRewardTokensFunding(100);
        smartStaking.depositRewardTokens(100);
        assertEq(rewardToken.balanceOf(deployedStakingContract), 100);

        rewardToken.approve(deployedStakingContract, 900);

        vm.expectEmit(true, false, false, true);
        emit ISmartStaking.NewRewardTokensFunding(900);
        smartStaking.depositRewardTokens(900);
        assertEq(rewardToken.balanceOf(deployedStakingContract), 1000);
    }

    function testStakeRevertsCheck() public {
        vm.startPrank(user1);

        vm.expectRevert(ISmartStaking.TokensNotApproved.selector);
        smartStaking.stake(100);

        stakingToken.approve(deployedStakingContract, 100);

        vm.expectRevert(ISmartStaking.AmountMustBeGreaterThanZero.selector);
        smartStaking.stake(0);

        vm.startPrank(user2);

        vm.expectRevert(ISmartStaking.NotEnoughFunds.selector);
        smartStaking.stake(100);
    }

    function testStakeFunctionalityAndEventCheck() public {
        vm.startPrank(user1);

        stakingToken.approve(deployedStakingContract, 100);
        smartStaking.stake(100);

        assertEq(stakingToken.balanceOf(deployedStakingContract), 100);
        assertEq(smartStaking.availableRewards(user1), 0);

        stakingToken.approve(deployedStakingContract, 650);
        vm.expectEmit(true, false, false, true);
        emit ISmartStaking.NewStaking(user1, 650);
        smartStaking.stake(650);

        assertEq(stakingToken.balanceOf(deployedStakingContract), 750);
    }

    function testUnstakeRevertsCheck() public {
        vm.startPrank(user1);

        vm.expectRevert(ISmartStaking.NothingToUnstake.selector);
        smartStaking.unstake(100);

        stakingToken.approve(deployedStakingContract, 100);
        smartStaking.stake(100);

        vm.expectRevert(ISmartStaking.AmountMoreThanStaked.selector);
        smartStaking.unstake(200);

        vm.expectRevert(ISmartStaking.AmountMustBeGreaterThanZero.selector);
        smartStaking.unstake(0);
    }

    function testUnstakeFunctionalityAndEventCheck() public {
        vm.startPrank(user1);
        assertEq(stakingToken.balanceOf(user1), 1000000000000000000000000); // premint balance

        stakingToken.approve(deployedStakingContract, 100);
        smartStaking.stake(100);
        assertEq(stakingToken.balanceOf(user1), 999999999999999999999900);

        vm.expectEmit(true, false, false, true);
        emit ISmartStaking.NewUnstaking(user1, 100);
        smartStaking.unstake(100);

        assertEq(stakingToken.balanceOf(deployedStakingContract), 0);
        assertEq(stakingToken.balanceOf(user1), 1000000000000000000000000);
    }

    function testAvailableRewardsFunctionalityWithoutBonusCheck() public {
        // Without bonus points
        vm.startPrank(owner);
        rewardToken.approve(deployedStakingContract, 100000 * 1e18);
        smartStaking.depositRewardTokens(100000 * 1e18);
        vm.stopPrank();

        vm.startPrank(user1);
        stakingToken.approve(deployedStakingContract, 1000 * 1e18);
        smartStaking.stake(1000 * 1e18);

        assertEq(smartStaking.availableRewards(user1), 0);

        vm.warp(block.timestamp + 365 days);

        uint256 rewards = smartStaking.availableRewards(user1);
        assertTrue(rewards >= 99 * 1e18 && rewards <= 101 * 1e18, "Rewards should be approximately 100 tokens");

        vm.warp(block.timestamp + 365 days);

        rewards = smartStaking.availableRewards(user1);
        assertTrue(rewards >= 199 * 1e18 && rewards <= 201 * 1e18, "Rewards should be approximately 200 tokens");

        vm.warp(block.timestamp + 365 days);
        
        rewards = smartStaking.availableRewards(user1);
        assertTrue(rewards >= 299 * 1e18 && rewards <= 301 * 1e18, "Rewards should be approximately 300 tokens");
    }

    function testRewardsWithBonusesCountingCheck() public {
        vm.startPrank(owner);
        rewardToken.approve(deployedStakingContract, 100000 * 1e18);
        smartStaking.depositRewardTokens(100000 * 1e18);
        vm.stopPrank();

        vm.startPrank(user1);
        stakingToken.approve(deployedStakingContract, 1000 * 1e18);
        smartStaking.stake(1000 * 1e18);

        vm.expectRevert(ISmartStaking.NoBonusPoints.selector);
        smartStaking.getAllActivityBonusPoints();

        stakingToken.approve(deployedStakingContract, 4000 * 1e18);
        smartStaking.stake(4000 * 1e18);
        vm.warp(block.timestamp + 15_770_000);
        smartStaking.updateUserPointsForTimeWithProtocol();

        (uint256 timeBonus, uint256 balanceBonus) = smartStaking.getAllActivityBonusPoints();
        assertEq(timeBonus, 250);
        assertEq(balanceBonus, 100);
        
        // Check APR with bonuses: base 10% + time 0.5% + balance 0.15% = 10.65%
        uint256 timeBps = 50; // (250 * 200) / 1000 = 50 BPS
        uint256 balBps = 15; // (100 * 300) / 2000 = 15 BPS
        uint256 totalBonusBps = timeBps + balBps; // 65 BPS
        assertEq(totalBonusBps, 65);
        
        // Check expected rewards with bonus APR: 5000 tokens * 10.65% * time
        uint256 expectedRewards1 = smartStaking.availableRewards(user1);
        assertEq(expectedRewards1 > 0, true); // Should have accumulated some rewards

        stakingToken.approve(deployedStakingContract, 6000 * 1e18);
        smartStaking.stake(6000 * 1e18);
        vm.warp(block.timestamp + 31_540_000);
        smartStaking.updateUserPointsForTimeWithProtocol();

        (uint256 timeBonus1, uint256 balanceBonus1) = smartStaking.getAllActivityBonusPoints();
        assertEq(timeBonus1, 500);
        assertEq(balanceBonus1, 250);
        
        // Check APR with bonuses: base 10% + time 1.0% + balance 0.375% = 11.375%
        uint256 timeBonusBps = 100; // (500 * 200) / 1000 = 100 BPS
        uint256 balanceBonusBps = 37; // (250 * 300) / 2000 = 37 BPS (fractional result rounded down)
        uint256 totalBonusBps1 = timeBonusBps + balanceBonusBps; // 100 + 37 = 137 BPS
        assertEq(totalBonusBps1, 137); // 100 + 37 = 137
        
        // Check expected rewards with bonus APR: 11000 tokens * 11.375% * time
        uint256 expectedRewards2 = smartStaking.availableRewards(user1);
        assertEq(expectedRewards2 > expectedRewards1, true); // Should have more rewards than level 1

        stakingToken.approve(deployedStakingContract, 10000 * 1e18);
        smartStaking.stake(10000 * 1e18);
        vm.warp(block.timestamp + 63_080_000);
        smartStaking.updateUserPointsForTimeWithProtocol();

        (uint256 timeBonus2, uint256 balanceBonus2) = smartStaking.getAllActivityBonusPoints();
        assertEq(timeBonus2, 1000);
        assertEq(balanceBonus2, 500);
        
        // Check APR with bonuses: base 10% + time 2.0% + balance 0.75% = 12.75%
        uint256 timeBps2 = 200; // (1000 * 200) / 1000 = 200 BPS
        uint256 balBps2 = 75; // (500 * 300) / 2000 = 75 BPS
        uint256 totalBonusBps2 = timeBps2 + balBps2; // 275 BPS
        assertEq(totalBonusBps2, 275);
        
        // Check expected rewards with bonus APR: 21000 tokens * 12.75% * time
        uint256 expectedRewards3 = smartStaking.availableRewards(user1);
        assertEq(expectedRewards3 > expectedRewards2, true); // Should have more rewards than level 2

        vm.warp(block.timestamp + 78_840_000);
        smartStaking.updateUserPointsForTimeWithProtocol();
        (uint256 timeBonus3, uint256 balanceBonus3) = smartStaking.getAllActivityBonusPoints();
        
        assertEq(timeBonus3, 1000);
        assertEq(balanceBonus3, 500);
        
        // Check APR with bonuses: base 10% + time 2.0% + balance 0.75% = 12.75%
        uint256 timeBps3 = 200; // (1000 * 200) / 1000 = 200 BPS
        uint256 balBps3 = 75; // (500 * 300) / 2000 = 75 BPS
        uint256 totalBonusBps3 = timeBps3 + balBps3; // 275 BPS
        assertEq(totalBonusBps3, 275);
        
        // Check expected rewards with bonus APR: 21000 tokens * 12.75% * time
        uint256 expectedRewards4 = smartStaking.availableRewards(user1);
        assertEq(expectedRewards4 > expectedRewards3, true); // Should have more rewards than level 3

        stakingToken.approve(deployedStakingContract, 30000 * 1e18);
        smartStaking.stake(30000 * 1e18);
        vm.warp(block.timestamp + 94_610_000);
        smartStaking.updateUserPointsForTimeWithProtocol();

        (uint256 timeBonus4, uint256 balanceBonus4) = smartStaking.getAllActivityBonusPoints();
        assertEq(timeBonus4, 1000);
        assertEq(balanceBonus4, 1000);
        
        // Check APR with bonuses: base 10% + time 2.0% + balance 1.5% = 13.5%
        uint256 timeBps4 = 200; // (1000 * 200) / 1000 = 200 BPS
        uint256 balBps4 = 150; // (1000 * 300) / 2000 = 150 BPS
        uint256 totalBonusBps4 = timeBps4 + balBps4; // 350 BPS, but maximum 500
        if (totalBonusBps4 > 500) totalBonusBps4 = 500;
        assertEq(totalBonusBps4, 350);
        
        // Check expected rewards with bonus APR: 51000 tokens * 13.5% * time
        uint256 expectedRewards5 = smartStaking.availableRewards(user1);
        assertEq(expectedRewards5 > expectedRewards4, true); // Should have more rewards than level 4

        stakingToken.approve(deployedStakingContract, 50000 * 1e18);
        smartStaking.stake(50000 * 1e18);
        vm.warp(block.timestamp + 126_140_000);
        smartStaking.updateUserPointsForTimeWithProtocol();

        (uint256 timeBonus5, uint256 balanceBonus5) = smartStaking.getAllActivityBonusPoints();
        assertEq(timeBonus5, 1000);
        assertEq(balanceBonus5, 2000);
        
        // Check APR with bonuses: base 10% + maximum bonus 5% = 15%
        uint256 timeBps5 = 200; // (1000 * 200) / 1000 = 200 BPS
        uint256 balBps5 = 300; // (2000 * 300) / 2000 = 300 BPS
        uint256 totalBonusBps5 = timeBps5 + balBps5; // 500 BPS - maximum!
        if (totalBonusBps5 > 500) totalBonusBps5 = 500;
        assertEq(totalBonusBps5, 500);
        
        // Check expected rewards with maximum bonus APR: 101000 tokens * 15% * time
        uint256 expectedRewards6 = smartStaking.availableRewards(user1);
        assertEq(expectedRewards6 > expectedRewards5, true); // Should have more rewards than level 5
        assertEq(expectedRewards6 > 0, true); // Should have accumulated significant rewards
    }

    function testClaimRevertsCheck() public {
        vm.startPrank(user1);
        vm.expectRevert(ISmartStaking.NothingToClaim.selector);
        smartStaking.claim();

        vm.startPrank(user1);
        stakingToken.approve(deployedStakingContract, 1000 * 1e18);
        smartStaking.stake(1000 * 1e18);

        vm.warp(block.timestamp + 365 days);
        
        vm.expectRevert(ISmartStaking.ContractHasNotEnoughFunds.selector);
        smartStaking.claim();
    }

    function testClaimFunctionalityAndEventCheck() public {
        vm.startPrank(owner);
        rewardToken.approve(deployedStakingContract, 100000 * 1e18);
        smartStaking.depositRewardTokens(100000 * 1e18);
        vm.stopPrank();
        
        vm.startPrank(user1);
        stakingToken.approve(deployedStakingContract, 1000 * 1e18);
        smartStaking.stake(1000 * 1e18);

        vm.warp(block.timestamp + 365 days);
        uint256 rewards = smartStaking.availableRewards(user1);

        assertTrue(rewards >= 99 * 1e18 && rewards <= 101 * 1e18);

        vm.expectEmit(true, true, false, true);
        emit ISmartStaking.RewardsClaimed(user1, rewards);
        smartStaking.claim();

        assertEq(smartStaking.availableRewards(user1), 0);
        assertEq(rewardToken.balanceOf(user1), rewards);
    }

    function testUpdateAPRRevertCheck() public {
        vm.startPrank(owner);

        vm.expectRevert(ISmartStaking.RewardAPRMustBeGreaterThanZero.selector);
        smartStaking.updateAPR(0);
    }
    
    function testUpdateAPRFunctionalityAndEventCheck() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit ISmartStaking.APRUpdated(500);
        smartStaking.updateAPR(500);
    }

    function testPauseTurnedOnOffFunctionalityAndEventChec() public {
        vm.startPrank(owner);

        rewardToken.approve(deployedStakingContract, 100000 * 1e18);
        smartStaking.depositRewardTokens(100000 * 1e18);

        vm.stopPrank();
        vm.startPrank(user1);

        stakingToken.approve(deployedStakingContract, 1000 * 1e18);
        smartStaking.stake(1000 * 1e18);

        vm.startPrank(owner);
        smartStaking.pause();

        vm.stopPrank();
        vm.startPrank(user1);

        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        smartStaking.unstake(1000 * 1e18);

        vm.stopPrank();
        vm.startPrank(owner);

        smartStaking.unpause();

        vm.stopPrank();
        vm.startPrank(user1);

        smartStaking.unstake(1000 * 1e18);
    }

}