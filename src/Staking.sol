// SPDX-License-Identifier: MIT
// Assuming that the contract is always pre-funded with reward tokens to serve users.
// Assuming that in Quickswap V3, a pool of stake token and reward token should have enough liquidity to serve users' trades.

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IStaking.sol";
import "./interfaces/ISwapRouter.sol";
import "forge-std/Test.sol";

/**
 * @title Staking Contract
 * @dev A contract for staking tokens, earning rewards.
 */
contract Staking is IStaking, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ERC-20 token to be staked
    IERC20 public stakingToken;

    // ERC-20 token used for rewards
    IERC20 public rewardToken;

    // Quickswap-V3 Router used for swapping reward token to staking token
    ISwapRouter immutable swapRouter;

    // Struct to store user information
    struct UserInfo {
        uint256 stakeAmount;
        uint256 lastUpdateBlock;
    }

    // Mapping to store user information
    mapping(address => UserInfo) public userInfo;

    // Fixed reward rate per block (0.01% per block)
    uint256 public rewardRate = 1; // 0.01% is 1 in BPS

    /**
     * @dev Constructor to initialize the staking contract.
     * @param _stakingToken Address of the ERC-20 token to be staked.
     * @param _rewardToken Address of the ERC-20 token used for rewards.
     * @param _swapRouter Address of the Quickswap-V3 Router for swapping tokens.
     */
    constructor(
        address _stakingToken,
        address _rewardToken,
        address _swapRouter
    ) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        swapRouter = ISwapRouter(_swapRouter);
        IERC20(_rewardToken).approve(_swapRouter, type(uint256).max);
    }

    /**
     * @dev Function to stake tokens into the contract.
     * @param amount The amount of tokens to stake.
     */
    function stake(uint256 amount) external override nonReentrant {
        require(amount > 0, "Amount must be greater than 0");

        // Transfer staking tokens to the contract
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        // Update user information
        UserInfo storage user = userInfo[msg.sender];
        
        user.stakeAmount += amount;
        user.lastUpdateBlock = block.number;

    }

    /**
     * @dev Function to withdraw staked tokens and rewards.
     */
    function unstake() external override nonReentrant {
       
        UserInfo storage user = userInfo[msg.sender];
        require(user.stakeAmount > 0, "Insufficient staked amount");
        uint256 rewardAmount = calculateEarnedRewards(userInfo[msg.sender]);
        if (rewardAmount > 0) {
            rewardToken.safeTransfer(msg.sender, rewardAmount);
        }
        stakingToken.safeTransfer(msg.sender, user.stakeAmount);
        
        // freeup storage
        delete userInfo[msg.sender];
    }

    /**
     * @dev Function to harvest rewards and unstake all tokens.
     * @param amountOutMin The minimum amount of swap token.
     */
    function harvestAndUnstake(
        uint256 amountOutMin
    ) external override nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 rewards = calculateEarnedRewards(user);
        if (rewards > 0) {
            user.stakeAmount += _swap(rewards, amountOutMin);
        }
        stakingToken.safeTransfer(msg.sender, user.stakeAmount);

        // freeup storage
        delete userInfo[msg.sender];
    }

    /**
     * @dev Function to harvest (compound) rewards.
     * @param amountOutMin The minimum amount of swap token.
     */
    function harvest(uint256 amountOutMin) external override nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 rewards = calculateEarnedRewards(user);
        require(rewards > 0, "No rewards to compound");
        // Swap and update user information
        user.stakeAmount += _swap(rewards, amountOutMin);
        user.lastUpdateBlock = block.number;
    }

    /**
     * @dev Function to get the total rewards earned by a user.
     * @param user User information to calculate rewards for.
     * @return Total rewards earned by the user.
     */
    function calculateEarnedRewards(
        UserInfo memory user
    ) public view returns (uint256) {
        uint256 blocksSinceLastUpdate = block.number - user.lastUpdateBlock;
        return (user.stakeAmount * rewardRate * blocksSinceLastUpdate) / 10000;
    }

    /**
     * @dev Internal function to swap reward tokens for staking tokens.
     * @param amountIn The amount of reward tokens to swap.
     * @param amountOutMin The minimum amount of staking tokens to receive after swapping.
     * @return The amount of staking tokens received after the swap.
     */
    function _swap(
        uint256 amountIn,
        uint256 amountOutMin
    ) internal returns (uint256) {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: address(rewardToken),
                tokenOut: address(stakingToken),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: amountOutMin,
                limitSqrtPrice: 0
            });
        return swapRouter.exactInputSingle(params);
    }
}
