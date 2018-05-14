pragma solidity ^0.4.23;

// todo: allow participants to be able to withdraw supported tokens if softcap not reached
// todo: allow participants to contribute other ethereum based cryptocurrency with approve function
// todo: then allow them to notify contract of approval
// todo: create a way to buy tokens using ether, update totalAllowed and specific phase allowed.
// todo: Also update totalContributions with amount of wei


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
        require(msg.sender == owner, "Only Owner Can Use This Function");
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
    function balanceOf(address tokenOwner) external view returns (uint balance);
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


contract AdvancedCrowdsale is Crowdsale, Owned{
    
    bool public isPaused;  // if crowdsale is paused
    bool public isStarted;  // if crowdsale has started
    bool public isEnded;  // if crowdsale has ended
    uint8 public phase;  // phase of sale
    uint public rewardTokensAvailable ;  // reduces with every purchase
    uint public tokensApprovedForReward; // constant amount after funding
    uint public minimumPurchase; // minimum purchase amount in wei. if 0 then no minimum
    uint public maximumPurchase; // maximum purchase amount in wei. if 0 then no maximum
    bool public refundAllowed; // if refund is allowed,
    
    // add to functions which should only execute if sale is on
    modifier saleIsOn{
        require(isStarted && !isEnded && !isPaused, "Sale Not Started, Paused Or Completed");
        _;
    }
    
    // add to functions which should only execute when sale is paused
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
        return (isEnded&&isStarted);  // if isStarted is True and isEnded is True then sale completed
    }
    
    // used by owner to pause or unpause sale
    function onlyOwnerPauseOrUnpause() public onlyOwner{
        require(isStarted&&!isEnded, "sale has not started");
        if(isPaused){
            isPaused = false;
        }else{
            isPaused = true;
        }
    }
    
    //used by owner to end sale
    function onlyOwnerEndSale() public onlyOwner{
        require(!isEnded);
        isEnded = true;
        
    }
    
    
    // used by owner to  change organizationWallet
    function onlyOwnerChangeOrgWallet(address _wallet) public onlyOwner{
        require(_wallet != address(0));
        organizationWallet = _wallet;
    }
    
    // used by owner to set a token for reward, if not set during deployment
    function onlyOwnerSetTokenForReward(address _tokenAddress) public onlyOwner onlyWhenPaused{
        require(isContract(_tokenAddress));  // address must be a contract
        
        // check balance of previous tokenForReward and transfer back to owner
        if (tokenForReward != address(0)){
            uint balance = tokenForReward.balanceOf(address(this));
            if(balance > 0){
                tokenForReward.transfer(owner, balance);
            }
        }
        
        // set rewardTokensAvailable and tokensApprovedForReward back to zero
        // set tokenForReward to new token address
        rewardTokensAvailable = 0;
        tokensApprovedForReward = 0;
        tokenForReward = token(_tokenAddress);
    }
    
    
    // used by owner to set name of token
    function onlyOwnerSetTokenRewardName(string _name) public onlyOwner isNotNullAddress{
        nameOfTokenForReward = _name;
        
    }
    
    // used by owner to start sale
    function onlyOwnerStartSale() public onlyOwner{
        require(!isEnded&&!isStarted);
        require(tokenForReward != address(0), "set a token to use for reward");
        require(tokensApprovedForReward > 0, "must send tokens to crowdsale using approveAndCall");
        phase = 1;
        isStarted = true;
        isPaused = false;
    }
    
    
    
    // set minimum purchase turned into ether equivalent. 100 == 1 ether
    // 10 equals 0.10 ether and so on
    function onlyOwnerSetMinimum(uint _minimum)public onlyOwner onlyWhenPaused{
        
        if(_minimum == 0){
            require(minimumPurchase != 0);
            minimumPurchase = 0;
        }else{
            uint minimumAmount = _minimum * 1 ether;
            minimumPurchase = minimumAmount / 100;
            require(minimumPurchase < maximumPurchase || maximumPurchase == 0); // minimum must be greater than max or max unlimited
        }
    }
    
    // set maximum purchase turned into ether equivalent. 100 == 1 ether
    // 10 equals 0.10 ether and so on
    function onlyOwnerSetMaximum(uint _maximum)public onlyOwner onlyWhenPaused{
        
        if(_maximum == 0){
            require(maximumPurchase != 0, "Already set to zero");
            maximumPurchase = _maximum; // sets to zero == no maximum, if you would like to remove individual caps
        }else{
            
            uint maximumAmount = _maximum * 1 ether;
            maximumPurchase = maximumAmount / 100;
            require(maximumPurchase > minimumPurchase);
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
    
    // use to approve refund or revoke approval 
    function onlyOwnerApproveRefund() public onlyOwner returns(bool) {
        require(isCompleted());
        
        if (refundAllowed == false){
            refundAllowed = true;
        }else{
            refundAllowed = false;
        }
    }
    
    
    
    
    // withdraw ether raised to Organization Wallet
    function onlyOwnerWithdraw() public onlyOwner  returns (bool){
        require(isCompleted());
        
        // get ether balance
        uint amount = address(this).balance;
        require(amount > 0, "No Ether In contract");
        
        // transfer balance of ether to Organization's Wallet 
        organizationWallet.transfer(amount);
        
        return true;
    
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
    
}

contract OPresale is AdvancedCrowdsale{
    
    mapping(address => bool) public whitelist;  // mapping of whitelisted addresses
    
    mapping(uint8 => mapping(address => uint)) public allowed;  // allowed is divided in phases, this can be used to lock tokens
    
    mapping(address => uint) public totalContributions; // used if refund required. stores total contribution of an address
    
    mapping(address => uint)totalAllowed; // used if refund required. stores total tokens to receive of an address
    
    mapping(uint8 => bool)phaseAbleToWithdraw; // if phase is able to withdraw
    
    mapping(address => bool) notAbleToGetRefund; // 
    
    uint public softcap;  // minimum to raise in ether
    
    
    event OPresaleFunded(address indexed _funder, uint _amount,address indexed _rewardToken, bytes _data); // log when contract is funded
    
    event TokensWithdrawn(address indexed _backer, address indexed _beneficiary, uint _amount);  // emitted when participant withdraws token
    
    event OPresaleDefunded(address indexed _funder, uint _amount,address indexed _rewardToken); // log when contract is funded
    
    event RefundSent(address indexed _receiver, uint _amount);

    modifier isWhitelisted(address _beneficiary) {
        require(whitelist[_beneficiary], "address not whitelisted");
        _;
    }
    
    modifier onlySoftcapReached(){
        require(weiRaised >= softcap, "softcap not reached");
        _;
    }
    
    
    constructor(address _orgWallet, address _tokenAddress, uint24 _rate, uint _softcap) public{
        
        isPaused = true;  // if sale is paused
        isStarted = false;  // if sale has started
        isEnded = false;  // if sale has ended
        
        organizationWallet = address(_orgWallet);  // beneficiary wallet
        tokenForReward = token(_tokenAddress);  // the address for the token being offered
        ratePer = _rate;  // reward token per ether
        softcap = _softcap * 1 ether;  // softcap is sent in ether, this converts to wei
        
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
        
        emit OPresaleFunded(_from, _tokens, _theToken, _data);
        
    }
    
    // used by owner to add an address to the whitelist
    function addToWhitelist(address _participant) external onlyOwner {
        whitelist[_participant] = true;
    }
    
    // used to add multiple addresses to whitelist
    function addManyToWhitelist(address[] _participants) external onlyOwner {
        for (uint256 i = 0; i < _participants.length; i++) {
          whitelist[_participants[i]] = true;
            
        }
        
    }
    
    // used to remove already added address from whitelist
    function removeFromWhitelist(address _participant) external onlyOwner {
        whitelist[_participant] = false;
        
    }
    
    // used to remove already added address from whitelist
    function removManyeFromWhitelist(address[] _participants) external onlyOwner {
        for (uint256 i = 0; i < _participants.length; i++) {
          whitelist[_participants[i]] = false;
        }
    }
    
    // validate pre purchase
    function _preValidatePurchase( uint256 _weiAmount) internal view isWhitelisted(msg.sender) {
        require(_weiAmount != 0);
    }
    
    // validate post purchase
    function _postValidatePurchase(uint _totalcontributed) internal view{
        // if minimum contribution is set (minimumPurchase > 0) then check if minimums met
       if(minimumPurchase > 0){
            require(_totalcontributed >= minimumPurchase, "contributions less than minimum");
        }
        
        // if maximum contribution is set (maximumPurchase > 0)
        if(maximumPurchase > 0){
            require(_totalcontributed <= maximumPurchase, "contributions greater than maximum");
        }
    }
    
    // return tokens to msg.sender will be receiving. can't check for others
    function tokensToReceive() public view returns (uint){
        return totalAllowed[msg.sender];
    }
    
    // can only get refund per phase, if bought in multiple phase must getRefund for each phase
    function getRefund() external  {
        
        require(refundAllowed, "refund Not Allowed");
        require(isCompleted());
        require(!notAbleToGetRefund[msg.sender], "Already withdrawn token, can not withdraw contributed ether"); // msg.sender must be able to get refund
        
        uint weiContributed = totalContributions[msg.sender];
        require(weiContributed > 0, "No Ether To Refund For This Phase");  // msg.sender must have contributed
        totalContributions[msg.sender] = 0;  // finds contributions of sender in phase turns to zero
        
        uint prevAllowed = totalAllowed[msg.sender];
        totalAllowed[msg.sender] = 0; // finds tokens to receive by phase turns to zero
        
        rewardTokensAvailable = rewardTokensAvailable.add(prevAllowed);  // add back to reward tokens available
        msg.sender.transfer(weiContributed);  // send wei contributed back
        emit RefundSent(msg.sender, weiContributed);
        
    }
    
    function getYourTokens(uint8 _phaseBought, address _beneficiary) public returns(bool success) {
        
        require(isCompleted(), "sale not completed yet");  // sale must have ended
        require(!refundAllowed, "refund of ether is being allowed, can not withdraw tokens"); // make sure refund not allowed (which might allow to withdraw wei and tokens)
        require(totalAllowed[msg.sender] > 0, "You Do Not Have Any Tokens"); // this will be zero if wei was refunded and will stop from getting ERC20 tokens also
        require(phaseAbleToWithdraw[_phaseBought], "Tokens Are Locked For That Phase");  // checks to make sure tokens bought in phase is unlocked
        
        uint payoutAmount = allowed[_phaseBought][msg.sender];  // tokens can't be partially withdrawn
        require(payoutAmount > 0, "You Have No Tokens In This Phase");
        allowed[_phaseBought][msg.sender] = 0;  // withdraws all tokens 
        totalAllowed[msg.sender] = totalAllowed[msg.sender].sub(payoutAmount);  // subtract from totalAllowed.
        notAbleToGetRefund[msg.sender] = true; // msg.sender is not able to get wei refunded after withdrawing tokens
        // send token to msg.sender if _beneficiary not provided
        if (_beneficiary == address(0)){
            success = tokenForReward.transfer(msg.sender, payoutAmount);
            require(success);
            emit TokensWithdrawn(msg.sender, msg.sender, payoutAmount);
        }
        // send token to _beneficiary if _beneficiary provided
        else {
             success = tokenForReward.transfer(_beneficiary, payoutAmount);
             require(success);
             emit TokensWithdrawn(msg.sender, _beneficiary, payoutAmount);
        }
    }
    
    function buyToken() public saleIsOn isWhitelisted(msg.sender) payable{
        uint weiAmount = msg.value;
        _preValidatePurchase(weiAmount);
        uint numOfTokens = weiAmount.mul(ratePer);
        require(rewardTokensAvailable >= numOfTokens);  // makes sure enough tokens are available
        
        uint totalContributed = totalContributions[msg.sender].add(weiAmount);
        _postValidatePurchase(totalContributed);
        totalContributions[msg.sender] = totalContributed;  // update amount after post validation
        
        
        weiRaised = weiRaised.add(weiAmount);  // add to total wei raised
        rewardTokensAvailable = rewardTokensAvailable.sub(numOfTokens);
        totalAllowed[msg.sender] = totalAllowed[msg.sender].add(numOfTokens); // add totals for
        allowed[phase][msg.sender] = allowed[phase][msg.sender].add(numOfTokens);
        
    
    }
    
    function onlyOwnerTransferRemainingTokens(address _beneficiary) public{
        require(isCompleted());
        require(rewardTokensAvailable > 0, "no reward token left");
        
        if(_beneficiary == address(0)){
            require(tokenForReward.transfer(msg.sender, rewardTokensAvailable)); // transfer remaing tokens
            emit OPresaleDefunded(msg.sender, rewardTokensAvailable, address(tokenForReward));
            rewardTokensAvailable = 0;
        }else{
            require(tokenForReward.transfer(_beneficiary, rewardTokensAvailable));
            emit OPresaleDefunded(_beneficiary, rewardTokensAvailable, address(tokenForReward));
            rewardTokensAvailable = 0;
        }
        
    }
    
    function onlyOwnerUnlockOrLockPhase(uint8 _phase) public onlyOwner returns(bool) {
        require(isCompleted());
        
        if (phaseAbleToWithdraw[_phase]){
            
            phaseAbleToWithdraw[_phase] = false;
        }else{
            phaseAbleToWithdraw[_phase] = true;
        }
        
        return true;
        
        
    }
    
    // withdraw ether raised to Organization Wallet if softcap is reached
    function onlyOwnerWithdraw() public onlyOwner onlySoftcapReached returns (bool){
        super.onlyOwnerWithdraw();
    
    }
    
    

}
