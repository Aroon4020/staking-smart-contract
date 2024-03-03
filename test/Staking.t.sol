// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/Staking.sol";

contract ERC20 {
    uint8 public constant decimals = 18;
    uint public immutable totalSupply;

    mapping(address => uint) public balanceOf;
    mapping (address => mapping (address => uint)) public allowance;

    constructor(uint supply) {
        balanceOf[msg.sender] = supply;
        totalSupply = supply;
    }

    function transfer(address to, uint amount) public returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint amount) public returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract ContractTest is Test {

    Staking staking;
    ERC20 stakingToken = new ERC20(100000 ether);
    ERC20 rewardToken = new ERC20(100000 ether);
    address user0 = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);

    function setUp() public {
        
        staking = new Staking(address(stakingToken), address(rewardToken), address(0xa12));
        rewardToken.transfer(address(staking), 1000 ether);
    }

    function testSingleStaker() public {

        stakingToken.transfer(user0,10 ether);
        vm.startPrank(user0);
        stakingToken.approve(address(staking), 1 ether);
        staking.stake(1 ether);
        assert(stakingToken.balanceOf(address(staking)) == 1 ether);
        
        vm.roll(block.number + 100);
        staking.unstake();
        assert(rewardToken.balanceOf(user0)==0.01 ether);//(amountstaked*reward per block*no of block)(1*0.0001*100)
        assert(stakingToken.balanceOf(address(staking)) == 0 ether);
        vm.stopPrank();
    }

    function test2Stakers() public {
        stakingToken.transfer(user0,10 ether);
        stakingToken.transfer(user1,10 ether);
        
        // 1st staker
        vm.startPrank(user0);
        stakingToken.approve(address(staking), 1 ether);
        staking.stake(0.5 ether);
        staking.stake(0.5 ether);
        assert(stakingToken.balanceOf(address(staking)) == 1 ether);
        
        // 2nd staker
        vm.startPrank(user1);
        stakingToken.approve(address(staking), 1 ether);
        staking.stake(1 ether);
        assert(stakingToken.balanceOf(address(staking)) == 2 ether);
        
        staking.unstake();
        assert(rewardToken.balanceOf(user0)==0 ether);//reward sould be zero as unstaking in same block.
        assert(stakingToken.balanceOf(address(staking)) == 1 ether);
        vm.stopPrank();

        vm.startPrank(user0);
        vm.roll(block.number + 100);
        staking.unstake();
        assert(rewardToken.balanceOf(user0)==0.01 ether);
        vm.stopPrank();
        
    }

    function testunstake() public {
        stakingToken.transfer(user0,10 ether);
        stakingToken.transfer(user1,10 ether);
        
        // 1st staker
        vm.startPrank(user0);
        stakingToken.approve(address(staking), 1 ether);
        staking.stake(1 ether);

        assert(stakingToken.balanceOf(address(staking)) == 1 ether);
        
        // 2nd staker
        vm.startPrank(user1);
        stakingToken.approve(address(staking), 1 ether);
        staking.stake(1 ether);
        assert(stakingToken.balanceOf(address(staking)) == 2 ether);
        staking.unstake();//this will revert
        vm.expectRevert();
        staking.unstake();
        vm.startPrank(user0);
        staking.unstake();
        
        vm.stopPrank();
    }

    function testUnstakeAndReward() public {
        stakingToken.transfer(user0,10 ether);
        stakingToken.transfer(user1,10 ether);
        
        // 1st staker
        vm.startPrank(user0);
        stakingToken.approve(address(staking), 0.5 ether);
        staking.stake(0.5 ether);

        assert(stakingToken.balanceOf(address(staking)) == 0.5 ether);
        
        // 2nd staker
        vm.startPrank(user1);
        stakingToken.approve(address(staking), 1 ether);
        staking.stake(1 ether);
        assert(stakingToken.balanceOf(address(staking)) == 1.5 ether);
        
        vm.roll(block.number + 1000);
        staking.unstake(); 
        assert(rewardToken.balanceOf(user1)==0.1 ether);   
        vm.expectRevert();
        staking.unstake();//this will revert

        vm.startPrank(user0);
        staking.unstake();
        assert(rewardToken.balanceOf(user0)==0.05 ether);
        vm.stopPrank();
    }
}