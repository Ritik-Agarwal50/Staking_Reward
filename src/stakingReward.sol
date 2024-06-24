// SPDX-License-Ientifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import "./interface/IERC20.sol";

contract stakingReward {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;

    address public owner;

    uint256 public rewardRate;
    uint256 public duration;
    uint256 public finishAt;
    uint256 public updateAt;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(IERC20 _stakingToken, IERC20 _rewardToken) {
        owner = msg.sender;
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not Auth bro :(");
        _;
    }

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updateAt = lastTimeRewardApplicable();
        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }
        _;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            ((rewardRate * (lastTimeRewardApplicable() - updateAt) * 1e18) /
                totalSupply);
    }

    function stake(uint256 _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return _min(finishAt, block.timestamp);
    }

    function withdraw(uint256 _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount  should be more than 0");
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        stakingToken.transfer(msg.sender, _amount);
    }

    function earned(address _account) public view returns (uint256) {
        return
            ((balanceOf[_account] *
                (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18) +
            rewards[_account];
    }

    function getReward() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.transfer(msg.sender, reward);
        }
    }

    function setRewardDuration(uint256 _duration) external onlyOwner {
        require(finishAt < block.timestamp, "not finished yet");
        duration = _duration;
    }

    function notifyRewardAmount(
        uint256 _amount
    ) external updateReward(msg.sender) {
        if (block.timestamp >= finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint256 remainingReward = (finishAt - block.timestamp) * rewardRate;
            rewardRate = (_amount + remainingReward) / duration;
        }
        require(rewardRate > 0, "rewardRate should be more than 0");
        require(
            rewardRate * duration <= rewardToken.balanceOf(address(this)),
            "reward amount is greate than balance"
        );
        finishAt = block.timestamp + duration;
        updateAt = block.timestamp;
    }

    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x <= y ? x : y;
    }
}
