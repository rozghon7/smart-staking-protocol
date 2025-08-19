# Smart Staking: Advanced DeFi Staking Protocol with Activity-Based Rewards

## 🚀 Overview

**Smart Staking is a sophisticated, gas-optimized, and highly secure DeFi staking protocol that combines traditional staking mechanics with innovative activity-based bonus systems.** Built on Solidity with comprehensive testing and security measures, this protocol offers users enhanced APR through dynamic bonus calculations while maintaining the reliability and efficiency expected in production DeFi applications. The project implements advanced reward distribution algorithms, comprehensive pause mechanisms, and robust access controls to ensure a secure and scalable staking experience.

## ✨ Features

* **🔄 Dynamic Reward Distribution:** Implements a sophisticated reward calculation system using `rewardPerTokenIndex` for accurate and fair reward distribution across all stakers.
* **⭐ Activity-Based Bonus System:** Users earn bonus APR points based on their interaction frequency and staking duration, creating an engaging and rewarding experience.
* **⚡ Gas-Optimized Operations:** Leverages efficient algorithms and minimal state changes to reduce gas costs for all staking operations.
* **🛡️ Comprehensive Security:** Implements OpenZeppelin's battle-tested security patterns including `Pausable`, `ReentrancyGuard`, and `Ownable` for maximum protection.
* **📊 Real-Time Reward Tracking:** Provides accurate `availableRewards` calculations that perfectly match actual claimable amounts, eliminating discrepancies.
* **🎯 Flexible Staking Options:** Supports various staking amounts with dynamic bonus calculations based on staked balance and time commitment.
* **⏸️ Emergency Controls:** Includes pause/unpause functionality for emergency situations while maintaining user fund security.
* **🧪 Rigorous Testing:** Comprehensive Foundry test suite covering all edge cases, security scenarios, and reward calculations.

## 🏗️ Architecture & Design

The Smart Staking ecosystem comprises several interconnected components:

### **Core Contracts**

1. **`SmartStaking.sol` (Main Contract):**
   * Manages the entire staking lifecycle including stake, unstake, and reward distribution
   * Implements sophisticated reward calculation algorithms with bonus point integration
   * Handles user activity tracking and bonus APR calculations
   * Provides emergency pause functionality for security incidents

2. **`ActivityTracker.sol` (Bonus Management):**
   * Tracks user interaction patterns and calculates activity-based bonus points
   * Manages time-based bonus accrual and APR enhancement calculations
   * Integrates seamlessly with the main staking contract for unified reward distribution

3. **`LibrarySmartStaking.sol` (Utility Functions):**
   * Contains optimized calculation functions for reward per token and bonus calculations
   * Provides reusable logic for complex mathematical operations
   * Ensures consistency across all reward calculations

### **Supporting Infrastructure**

4. **`ISmartStaking.sol` (Interface):**
   * Defines the complete contract interface for external integrations
   * Ensures type safety and clear contract interactions
   * Includes all public functions and events for comprehensive API coverage

5. **`ERC20MockRewardToken.sol` & `ERC20MockStakingToken.sol`:**
   * Mock ERC20 tokens for testing and development purposes
   * Implements standard ERC20 functionality with additional testing features
   * Enables comprehensive testing of all staking scenarios

## 🛠️ Development Setup

To set up the project locally for development and testing:

### **Prerequisites**
* **Foundry Framework:** Latest version for Solidity development and testing
* **Node.js:** Version 16+ for package management (if using additional tools)
* **Git:** For version control and dependency management

### **Installation Steps**

1. **Clone the repository:**
```bash
git clone <your-repository-url>
cd staking_alpha
```

2. **Install Foundry (if not already installed):**
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

3. **Install OpenZeppelin contracts:**
```bash
forge install OpenZeppelin/openzeppelin-contracts --no-commit
```

4. **Build the project:**
```bash
forge build
```

## 🚀 Deployment

### **Deployment Process**

1. **Deploy Mock Tokens (for testing):**
```bash
# Deploy staking token
forge create --rpc-url <YOUR_RPC_URL> --private-key <YOUR_PRIVATE_KEY> \
    src/ERC20MockStakingToken.sol:ERC20MockStakingToken

# Deploy reward token  
forge create --rpc-url <YOUR_RPC_URL> --private-key <YOUR_PRIVATE_KEY> \
    src/ERC20MockRewardToken.sol:ERC20MockRewardToken
```

2. **Deploy Activity Tracker:**
```bash
forge create --rpc-url <YOUR_RPC_URL> --private-key <YOUR_PRIVATE_KEY> \
    src/ActivityTracker/ActivityTracker.sol:ActivityTracker
```

3. **Deploy Smart Staking Contract:**
```bash
forge create --rpc-url <YOUR_RPC_URL> --private-key <YOUR_PRIVATE_KEY> \
    src/SmartStaking/SmartStaking.sol:SmartStaking \
    --constructor-args <STAKING_TOKEN_ADDRESS> <REWARD_TOKEN_ADDRESS> <ACTIVITY_TRACKER_ADDRESS> <REWARD_APR>
```

### **Configuration Parameters**

* **`REWARD_APR`:** Annual Percentage Rate for base rewards (e.g., 1000 = 10%)
* **`STAKING_TOKEN_ADDRESS`:** Address of the ERC20 token users will stake
* **`REWARD_TOKEN_ADDRESS`:** Address of the ERC20 token distributed as rewards
* **`ACTIVITY_TRACKER_ADDRESS`:** Address of the deployed ActivityTracker contract

## 💡 Usage Examples

### **Basic Staking Operations**

1. **Staking Tokens:**
```solidity
// Approve tokens first
stakingToken.approve(smartStakingAddress, amount);

// Stake tokens
smartStaking.stake(amount);
```

2. **Checking Available Rewards:**
```solidity
uint256 rewards = smartStaking.availableRewards(userAddress);
```

3. **Claiming Rewards:**
```solidity
smartStaking.claim();
```

4. **Unstaking Tokens:**
```solidity
smartStaking.unstake(amount);
```

### **Advanced Features**

5. **Activity Bonus Updates:**
```solidity
// Update user activity points (can be called by any user)
smartStaking.updateUserPointsForTimeWithProtocol();
```

6. **Emergency Pause (Owner only):**
```solidity
smartStaking.pause();   // Pause all operations
smartStaking.unpause(); // Resume operations
```

## 🧪 Testing

The project includes a comprehensive test suite covering all functionality:

### **Running Tests**

```bash
# Run all tests
forge test

# Run with verbose output
forge test -vvv

# Run specific test file
forge test --match-contract TestActivityTrackerAndSmartStaking

# Run with gas reporting
forge test --gas-report
```

### **Test Coverage**

The test suite covers:
* ✅ **Core Staking Logic:** Stake, unstake, and reward calculations
* ✅ **Reward Distribution:** Accurate reward tracking and claiming
* ✅ **Bonus System:** Activity-based APR enhancement calculations
* ✅ **Security Features:** Pause/unpause functionality and access controls
* ✅ **Edge Cases:** Zero balances, maximum values, and boundary conditions
* ✅ **Integration Tests:** Full contract interaction scenarios
* ✅ **Error Handling:** Custom error messages and revert conditions

## 🔒 Security Features

This project prioritizes security through multiple layers of protection:

### **Access Control**
* **Ownable Pattern:** Critical functions restricted to contract owner
* **Pausable Operations:** Emergency pause capability for security incidents
* **Reentrancy Protection:** Guards against reentrancy attacks

### **Mathematical Safety**
* **Precision Handling:** Uses PRECISION_FACTOR to avoid integer truncation issues
* **Safe Math Operations:** Leverages Solidity's built-in overflow protection
* **Consistent Calculations:** Unified reward calculation algorithms across all functions

### **State Management**
* **Atomic Operations:** Critical state changes happen atomically
* **Validation Checks:** Comprehensive input validation and balance checks
* **Event Emission:** All important state changes emit events for transparency

## 📊 Technical Specifications

### **Key Parameters**
* **Base APR:** Configurable annual percentage rate for rewards
* **Bonus Points:** Dynamic calculation based on user activity and staking duration
* **Precision Factor:** 1e18 for high-precision calculations
* **Minimum Staking:** No minimum staking requirements
* **Maximum Staking:** Limited only by available token supply

### **Gas Optimization**
* **Efficient Storage:** Optimized storage patterns for gas efficiency
* **Minimal State Changes:** Batch operations where possible
* **Library Usage:** External libraries for complex calculations

## 🚨 Emergency Procedures

### **Pause Protocol**
In case of security concerns or emergency situations:

1. **Owner can pause the contract:**
```solidity
smartStaking.pause();
```

2. **All staking operations are suspended:**
* Users cannot stake new tokens
* Users cannot unstake existing tokens
* Users cannot claim rewards
* Emergency functions remain accessible to owner

3. **Resume operations:**
```solidity
smartStaking.unpause();
```

## 📈 Performance & Scalability

### **Current Capabilities**
* **Tested with:** Multiple users, various staking amounts, extended time periods
* **Gas Efficiency:** Optimized for cost-effective operations
* **Scalability:** Designed to handle increasing user bases and token amounts

### **Future Enhancements**
* **Multi-token Support:** Potential for multiple staking and reward tokens
* **Advanced Bonus Algorithms:** More sophisticated activity tracking
* **Governance Integration:** DAO-based parameter management
* **Cross-chain Compatibility:** Multi-chain deployment support

## 🤝 Contributing

We welcome contributions to improve the Smart Staking protocol:

### **Development Guidelines**
* Follow Solidity best practices and style guides
* Ensure comprehensive test coverage for new features
* Update documentation for any API changes
* Follow the existing code structure and patterns

### **Testing Requirements**
* All new features must include comprehensive tests
* Tests should cover edge cases and error conditions
* Gas optimization should be considered for new functions
* Security implications should be thoroughly reviewed

## 📄 License

This project is licensed under the MIT License.

## 📧 Contact & Support

For questions, suggestions, or collaboration opportunities:

* **GitHub:** [rozghon7](https://github.com/rozghon7)
* **Email:** rozgonnni@gmail.com
* **LinkedIn:** [Mykyta Rozghon](https://www.linkedin.com/in/mykyta-rozghon-b1671637a/)

## 🙏 Acknowledgments

* **OpenZeppelin:** For battle-tested security contracts and libraries
* **Foundry:** For the excellent development and testing framework
* **Ethereum Community:** For continuous innovation and best practices

---

**⚠️ Disclaimer:** This software is provided "as is" without warranty. Users should conduct their own security audits before using in production environments. The developers are not responsible for any financial losses or damages resulting from the use of this software.
