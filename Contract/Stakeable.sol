pragma solidity ^0.8.0;

import "SafeMath.sol";

contract Stakeable{
    using SafeMath for uint256;

    uint256 constant stakingTime = 1 minutes;
    uint256 stakingIndex;
    uint256 stakingSince;
    uint256 stakingReward;
    

    struct Stake{
        uint256 amount;
        uint256 since;
    }

    mapping (address => mapping(uint256 => Stake)) public countStake;
    mapping(address => uint256) public ownStaked;
   
 
    function creatingStake(uint256 _amount) internal{
        stakingIndex = ownStaked[msg.sender]+1;
        countStake[msg.sender][stakingIndex].amount = _amount;
        countStake[msg.sender][stakingIndex].since = block.timestamp;
        ownStaked[msg.sender]++;
        stakingIndex++;
        
    }
 
    function calculateStakeAward(address _add, uint256 _index, uint256 _stakingReward) internal view returns(uint256, uint256){
        uint256 stakingAmount = countStake[_add][_index].amount;
        return (stakingAmount, stakingAmount/_stakingReward);
    }
//uint256 statusTime = block.timestamp - countStake[msg.sender][_index].since; , (stakingTime - statusTime)
    function _withdrawStake(address _add, uint256 _index, uint256 stakingTimeValue, uint256 _stakingReward) internal{
        require(ownStaked[msg.sender]>0, "No withdrawable staking");
	require(ownStaked[msg.sender]>=0, "No withdrawable staking");
        stakingSince = countStake[msg.sender][_index].since;
        require(stakingSince + stakingTime * stakingTimeValue <= block.timestamp, "Stake time isn't over yet");
        (,stakingReward) = calculateStakeAward(_add, _index, _stakingReward);
        uint256 q = ownStaked[msg.sender];
        for(uint i =_index; i <= q ; i++){
            if(i == _index){
                countStake[msg.sender][_index].amount = 0;
                countStake[msg.sender][_index].since = 0;
                ownStaked[msg.sender]--;
            }else{
                countStake[msg.sender][i-1].amount = countStake[msg.sender][i].amount;
                countStake[msg.sender][i-1].since = countStake[msg.sender][i].since;
            }
        }
        countStake[msg.sender][q].amount = 0;
        countStake[msg.sender][q].since = 0;
    }

}