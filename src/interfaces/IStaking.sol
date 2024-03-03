// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IStaking {
    function stake(uint256 amount) external;
    function unstake() external;
    function harvest(uint256 amountOutMin) external;
    function harvestAndUnstake(uint256 amountOutMin) external; 
}