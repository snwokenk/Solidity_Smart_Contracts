pragma solidity ^0.4.23;

// For safe math operations
library SafeMath {
    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        assert(c >= a);
    }
    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }
    function mul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        assert(a == 0 || c / a == b);
    }
    function div(uint a, uint b) internal pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
}

// sets owner of contract, allows for ownership transfer
contract Owned {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only Owner Can Call This function");
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}

// basic token implementation, with only required functions
interface token{
    function approve(address _spender, uint _value) external returns (bool success);
    function transferFrom(address _from, address _to, uint _tokens) external returns (bool success);
    function transfer(address _to, uint _value)external returns (bool success);
}

// basic Crowdsale contract
contract Crowdsale{
    
    using SafeMath for uint;
    
    // wallet in which ether will be sent to
    address public organizationWallet;
    
    // token to be used fo reward
    token public tokenForReward;
    
    // name of tokenForReward
    string public nameOfTokenForReward;
    
    // How many token units a buyer gets per wei
    uint24 public ratePer;
    
    // amount raised in wei
    uint public weiRaised;
    
    // event logging purchase of token
    event TokenPurchase(address indexed purchaser, uint256 value, uint256 amount);
    
    
    
    
    modifier isNotNullAddress{
         require(tokenForReward != address(0));
         _;
    }
    
    modifier isNotNullWallet{
        require(organizationWallet != address(0));
        _;
    }
    
    function etherRaised() public view returns(uint){
        return weiRaised / 1 ether;
    }
    
}


contract AdvanceCrowdsale is Crowdsale, Owned{
    
    // is paused
    bool public isPaused;
    
    // has started
    bool public isStarted;
    
    // has ended
    bool public isEnded;
    
    // which phase is sale on
    uint8 public phase;
    
    uint public rewardTokensAvailable ;  // reduces with every purchase
    uint public tokensApprovedForReward; // constant amount after funding
    uint public minimumPurchase; // minimum purchase amount in wei. if 0 then no minimum
    uint public maximumPurchase; // maximum purchase amount in wei. if 0 then no maximum
    
    // add to functions which should only execute if sale is on
    modifier saleIsOn{
        require(isStarted && !isEnded && !isPaused, "sale not on");
        _;
    }
    
    modifier onlyWhenPaused{
        if(!isPaused && isStarted) revert();
        _;
    }
    
    // returns if crowdsale is accepting purchase
    function isAcceptingPurchase() public view returns(bool){
        
        return (isStarted && !isEnded && !isPaused);
    }
    
    // returns if crowdsale has been completed
    function isCompleted() public view returns(bool){
        return (isEnded&&isStarted);
    }
    
    // used by owner to pause or unpause sale
    function pauseOrUnpause() public onlyOwner{
        require(isStarted&&!isEnded, "sale has not started");
        if(isPaused){
            isPaused = false;
        }else{
            isPaused = true;
        }
    }
    
    //used by owner to end sale
    function endSale() public onlyOwner{
        require(!isEnded);
        isEnded = true;
        
    }
    
    
    
    // change organizationWallet
    function changeOrgWallet(address _wallet) public onlyOwner{
        require(_wallet != address(0));
        organizationWallet = _wallet;
    }
    
    // set a token for reward
    function setTokenForReward(address _tokenAddress) public onlyOwner{
        require(isContract(_tokenAddress));
        
        tokenForReward = token(_tokenAddress);
    }
    
    
    // set name of token
    function setNameOfTokenForReward(string _name) public onlyOwner isNotNullAddress{
        nameOfTokenForReward = _name;
        
    }
    
    
    // function used to check if address is a contract
    function isContract(address _addr) internal view returns (bool is_contract) {
      uint length;
      assembly {
            //retrieve the size of the code on target address, this needs assembly
            length := extcodesize(_addr)
      }
      return (length>0);
    }
    
    // used by owner to start sale
    function startSale() public onlyOwner{
        require(!isEnded&&!isStarted);
        require(tokenForReward != address(0), "set a token to use for reward");
        require(tokensApprovedForReward > 0, "must send tokens to crowdsale using approveAndCall");
        phase = 1;
        isStarted = true;
        isPaused = false;
    }
    
    
    
    // set minimum purchase turned into ether equivalent. 100 == 1 ether
    // 10 equals 0.10 ether and so on
    function onlyOwnerSetMinimum(uint24 _minimum)public onlyOwner onlyWhenPaused{
        
        if(_minimum == 0){
            require(minimumPurchase != 0);
            minimumPurchase = _minimum;
        }else{
            uint24 minimumAmount = _minimum/100;
            minimumPurchase = uint(minimumAmount * 1 ether);
        }
    }
    
    // set maximum purchase turned into ether equivalent. 100 == 1 ether
    // 10 equals 0.10 ether and so on
    function onlyOwnerSetMaximum(uint24 _maximum)public onlyOwner onlyWhenPaused{
        
        if(_maximum == 0){
            require(maximumPurchase != 0, "Already set to zero");
            maximumPurchase = _maximum; // sets to zero == no maximum
        }else{
            require(_maximum > minimumPurchase, "maximum must be greater than minimumPurchase");
            uint24 maximumAmount = _maximum/100;
            maximumPurchase = uint(maximumAmount * 1 ether);
        }
    }
    
    // used to change rate of tokens per ether
    function onlyOwnerChangeRate(uint24 _rate)public onlyOwner onlyWhenPaused returns (bool success){
        ratePer = _rate;
        return true;
    }
    
    // change the phase
    function onlyOwnerChangePhase(uint8 _phase) public onlyOwner onlyWhenPaused returns (bool success){
        phase = _phase;
        return true;
    }
    
    function onlyOwnerChangeWallet(address _newWallet) public onlyOwner onlyWhenPaused returns(bool success){
        require(!isContract(_newWallet));
        
        organizationWallet = _newWallet;
        return true;
    }
    // withdraw ether raised to Organization Wallet
    function onlyOwnerWithdraw() external onlyOwner  returns (bool){
        require(isCompleted());
        
        // get ether balance
        uint amount = address(this).balance;
        require(amount > 0);
        
        // transfer balance of ether to Organization's Wallet 
        organizationWallet.transfer(amount);
        
        return true;
    
    }
    
    
}

contract OMainSale is AdvanceCrowdsale{
    
    mapping(address => uint) public allowed;  // mapping of address and tokens allowed for withdrawal
    mapping(address => uint) public contributions;
    event OMainSaleFunded(address indexed _funder, uint _amount,address indexed _rewardToken, bytes _data); // log when contract is fund
    event TokensWithdrawn(address indexed _backer, address indexed _beneficiary, uint _amount);
    
    
    constructor(address _orgWallet, address _tokenAddress, uint24 _rate) public{
        
        isPaused = true;
        isStarted = false;
        isEnded = false;
        
        organizationWallet = address(_orgWallet);
        tokenForReward = token(_tokenAddress);
        ratePer = _rate;
        
    }
    
    // called when sent spending approval using approveAndCall() of token
    function receiveApproval(address _from, uint _tokens, address _theToken, bytes _data) public{
        
        require(address(tokenForReward) == address(_theToken));
        require(address(_from) == owner, "must be funded by owner");
        require(tokensApprovedForReward == 0 && _tokens > 0);
        
        // sets the total tokens available
        tokensApprovedForReward = _tokens;
        rewardTokensAvailable = tokensApprovedForReward;
        
        bool success = token(_theToken).transferFrom(_from, this, _tokens);
        
        require(success);
        
        emit OMainSaleFunded(_from, _tokens, _theToken, _data);
        
    }
    
    // used to buy tokens, will revert if sale isn't on
    function buyToken() public saleIsOn payable{
        uint weiAmount = msg.value;
        _preValidatePurchase(weiAmount);
        uint numOfTokens = weiAmount.mul(ratePer);
        
        require(rewardTokensAvailable >= numOfTokens);
        weiRaised = weiRaised.add(weiAmount);
        contributions[msg.sender] = contributions[msg.sender].add(weiAmount);
        
        _postValidatePurchase(msg.sender);
        rewardTokensAvailable = rewardTokensAvailable.sub(numOfTokens);
        allowed[msg.sender] = allowed[msg.sender].add(numOfTokens);
        
        emit TokenPurchase(msg.sender, weiAmount, numOfTokens);
        
        
    }
    
    
    // return tokens to msg.sender will be receiving. can't check for others
    function tokensToReceive() public view returns (uint){
        return allowed[msg.sender];
    }
    
    // used by participants to get withdraw token into wallet. must be called by 
    function getYourTokens(address _beneficiary) public returns(bool success) {
        
        // sale must have have ended
        require(allowed[msg.sender] > 0);
        require(isCompleted());
        
        uint payoutAmount = allowed[msg.sender];
        allowed[msg.sender] = 0;
        
        if (_beneficiary == address(0)){
            success = tokenForReward.transfer(msg.sender, payoutAmount);
            require(success);
            emit TokensWithdrawn(msg.sender, msg.sender, payoutAmount);
        }else {
             success = tokenForReward.transfer(_beneficiary, payoutAmount);
             require(success);
             emit TokensWithdrawn(msg.sender, _beneficiary, payoutAmount);
        }
    }
    
    
    function _preValidatePurchase( uint256 _weiAmount) internal pure {
        require(_weiAmount != 0);
    }
    
    
    /** 
     * validate after purchase 
    */
    function _postValidatePurchase(address _sender) internal view{
        // check minimums
       if(minimumPurchase > 0){
            require(contributions[_sender] >= minimumPurchase, "contributions less than minimum");
        }
        
        // check maximums
        if(maximumPurchase > 0){
            require(contributions[_sender] <= maximumPurchase, "contributions greater than maximum");
        }
    }
    
    
}
