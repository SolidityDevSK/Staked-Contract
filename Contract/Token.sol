pragma solidity ^0.8.0;

import 'ERC20.sol';
import 'IERC20.sol';
import 'IUniswapV2Pair.sol';
import 'IUniswapV2Router01.sol';
import 'Address.sol';
import 'IUniswapV2Factory.sol';
import 'IUniswapV2Router02.sol';
import 'SafeMath.sol';
import 'Context.sol';
import 'Ownable.sol';
import 'Stakeable.sol';

// 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
// 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2

contract DuzenlemeContract is Context, ERC20, Ownable, Stakeable {

    using SafeMath for uint256;

    IUniswapV2Router02 public immutable uniswapV2Router;
    IUniswapV2Router02 _uniswapV2Router;
    address public immutable uniswapV2Pair;
    mapping (address => uint256) private stakeList;
    mapping(address => bool) public isBlacklisted;
    mapping(address => bool) public isExcludedFromFee;

    uint256 public liquidityFee = 5;

    //Select Token İnformations
    string tokenName = "name";
    string tokenSymbol = "symbol"; 
    uint256 tokenDecimals = 18;
    uint256 tokenTotalSupply = 1 * 10**3 * 10**tokenDecimals;
    
    
    address public burnWallet;
    address public stakingWallet;

    // Stake Settings
    uint256 supplyRate = 2;
    uint256 stakingTimeValue = 1;
    uint256 public stakingPerReward = 100;
    uint256 maxTokenTotalSupply = tokenTotalSupply * supplyRate;
    bool public isOnStake = false;

    // PancakeSwap Settings
    uint256 public minTokensBeforeSwap = 1000*10**tokenDecimals; 
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    uint256 nonce;
    
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor () ERC20(tokenName, tokenSymbol, tokenDecimals) {
        
        stakingWallet = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        burnWallet = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
        _mint(msg.sender, tokenTotalSupply/2);
        _mint(burnWallet, tokenTotalSupply/2);
        isExcludedFromFee[stakingWallet] = true;
        isExcludedFromFee[burnWallet] = true;
        isExcludedFromFee[msg.sender] = true;
        
        _uniswapV2Router = IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3); 

        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
    }
    
    /*
        override the internal _transfer function so that we can
        take the fee, and conditionally do the swap + liquditiy
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(!isBlacklisted[from] && !isBlacklisted[to], "This address is blacklisted!");
        uint256 contractTokenBalance = balanceOf(address(this));
        bool overMinTokenBalance = contractTokenBalance >= minTokensBeforeSwap;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            msg.sender != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            swapAndLiquify(contractTokenBalance);
            
        }

        if(isExcludedFromFee[from] || isExcludedFromFee[to]){    
            super._transfer(from, to, amount);
        } else {
            uint liquidityAmount = amount.mul(liquidityFee).div(10**2);
            uint tokensToTransfer = amount.sub(liquidityAmount);
                                
            super._transfer(from, address(this), liquidityAmount);
            super._transfer(from, to, tokensToTransfer);
        }    
    }

        /**
    * Add functionality like burn to the _stake afunction
    *
     */
    function stake(uint256 _amount) public{
      require(isOnStake, "Staking is not active");
      uint256 wilBeMaxTokenTotalSupply = tokenTotalSupply + _amount *  1 / stakingPerReward;
      // Make sure staker actually is good for it
      require(_amount < balanceOf(msg.sender), "Cannot stake more than you own");
      require(wilBeMaxTokenTotalSupply <= maxTokenTotalSupply, "The amount of tokens has reached the maximum amount!");
      creatingStake(_amount);
                // Burn the amount of tokens on the sender
      _transfer(msg.sender, stakingWallet, _amount);
    }

    
     /**
    * @notice withdrawStake is used to withdraw stakes from the account holder
     */
    function withdrawStake() public {
        (uint256 _amount , uint256 _reward) = calculateStakeAward(msg.sender, stakingPerReward);
        _withdrawStake(msg.sender, stakingTimeValue, stakingPerReward);
       _mint(msg.sender, _reward);
       _burn(burnWallet, _reward);
       _transfer(stakingWallet, msg.sender, _amount);
    }


    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);
        

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }
    
    receive() external payable {}

    function setLiquidityFee(uint32 newFee) public onlyOwner{
        liquidityFee = newFee;
    }
    function updateMinTokensBeforeSwap(uint256 val) public onlyOwner{
        minTokensBeforeSwap = val;
    }
    function setSupplyRate(uint256 _rate) public onlyOwner{
        supplyRate = _rate;
    }
    
    function burnToken(uint256 amount) public onlyOwner{
        tokenTotalSupply = tokenTotalSupply.sub(amount);
        _burn(burnWallet, amount);
    }

    // Stake set Values
    function changeStakeTime(uint256 _time) public onlyOwner {
        stakingTimeValue = _time;
    }
    function changeRewardPerRate (uint256 _value) public onlyOwner {
        stakingPerReward = _value;
    }
    function calculateStakingTime() public view returns(uint256){
        return (stakingTime * stakingTimeValue);
    }
    function changeBurnWallet (address _add) public onlyOwner{
        burnWallet = _add;
    } 
     function changeStakeWallet (address _add) public onlyOwner{
        stakingWallet = _add;
    } 

    function updateSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
    }

    function blacklistAddress(address account, bool value) public onlyOwner {
        isBlacklisted[account] = value;
    }

    function _changeStakeStatus () public onlyOwner {
        isOnStake = !isOnStake;
    }

    function withdrawAnyToken(address _recipient, address _ERC20address, uint256 _amount) public onlyOwner returns(bool) {
        require(_ERC20address != uniswapV2Pair, "Can't transfer out LP tokens!");
        require(_ERC20address != address(this), "Can't transfer out contract tokens!");
        IERC20(_ERC20address).transfer(_recipient, _amount); //use of the _ERC20 traditional transfer
        return true;
    }

  function withdrawContractBalance() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
    
}