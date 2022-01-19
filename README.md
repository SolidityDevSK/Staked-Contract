# Staked-Contract


In the current version 0.8, removing an element from the list in solidity causes an empty index number. Although it is still not possible to do some things in Solidity, we are working on it. I don't know if it's the best but my solution;



for(uint i =_index; i <= q ; i++){
            if(i == _index){
                countStake[msg.sender][_index].amount = 0;
                countStake[msg.sender][_index].since = 0;
                ownStaked[msg.sender]--;
            }if(i > _index){
                countStake[msg.sender][i-1].amount = countStake[msg.sender][i].amount;
                countStake[msg.sender][i-1].since = countStake[msg.sender][i].since;
            }
        }
        countStake[msg.sender][q].amount = 0;
        countStake[msg.sender][q].since = 0;
    }


It has been designed considering the fact that the number of elements of the list is not too large. Who wants to stake 100 different stakes :) If I see such a request, I can reconsider the method. 
