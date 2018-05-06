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

// ERC223 receiving contract base implementation
contract ContractReceiver {
    
    function tokenFallback(address _from, uint _value, bytes _data) public;
}

// interface ERC223/ERC20
contract ERC20Interface {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address _to, uint _value)public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Transfer(address indexed from, address indexed to, uint value, bytes data);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
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
        require(msg.sender == owner);
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



// implement base variables and functions
contract StandardToken is ERC20Interface, Owned{
    
    using SafeMath for uint;
    
    string public symbol;
    string public  name;
    
    // 18 is standard
    uint8 public decimals;
    
    // total supply of tokens
    uint public _totalSupply;
    
    // mapping of address to balance
    mapping(address => uint) balances;
    
    //mapping of address allowing, to adddress allowed and amount allowed for
    //transfer
    mapping(address => mapping(address => uint)) allowed;
    
    //event to tell when token transferred to a contract
    event TokenTransferredToContract(address indexed from, address indexed to, uint value, bytes data);
    
    
    
    // ------------------------------------------------------------------------
    // Total supply
    // ------------------------------------------------------------------------
    function totalSupply() public view returns (uint) {
        return _totalSupply;
    }
    
    // ------------------------------------------------------------------------
    // Get the token balance for account `tokenOwner`
    // ------------------------------------------------------------------------
    function balanceOf(address tokenOwner) public view returns (uint balance) {
        return balances[tokenOwner];
    }
    
    // For ERC20 transfer
    function transfer(address _to, uint _value)public returns (bool success){
        bytes memory empty;
        require(_value >= 0);
        require(balances[msg.sender] >= _value);

        // subtract from senders balance
        balances[msg.sender] = balances[msg.sender].sub(_value);
        
        // add to receiving contracts balance
        balances[_to] = balances[_to].add(_value);
        
        if(isContract(_to)){
            
            ContractReceiver receiver = ContractReceiver(_to);
            receiver.tokenFallback(msg.sender, _value, empty);
            emit TokenTransferredToContract(msg.sender, _to, _value,empty);
            emit Transfer(msg.sender, _to, _value, empty);
        }else{
            emit Transfer(msg.sender, _to, _value);
        }
        
        return true;
    }
    
    
    // sender approves withdrawal of tokens. no checks needed
    function approve(address _spender, uint _value) public returns (bool success){
        
        require(_value > 0);
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    
    // return tokens allowed to spend from tokenOwner by spender
    function allowance(address _tokenOwner, address _spender) public view returns (uint remaining){
        return allowed[_tokenOwner][_spender];
    }
    
    
    // transfer tokens approved to spend
    function transferFrom(address _from, address _to, uint _tokens) public returns (bool success){
        
        // checks
        require(_tokens > 0);
        require(allowed[_from][msg.sender] >= _tokens);
        
        balances[_from] = balances[_from].sub(_tokens);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_tokens);
        balances[_to] = balances[_to].add(_tokens);
        emit Transfer(_from, _to, _tokens);
        return true;
    }

    
    // function used to check if address is a contract
    function isContract(address _addr) private view returns (bool is_contract) {
      uint length;
      assembly {
            //retrieve the size of the code on target address, this needs assembly
            length := extcodesize(_addr)
      }
      return (length>0);
    }
    
    
    
}

// basic interface of contract implementing receiveApproval function
contract ApproveAndCallFallBack {
    function receiveApproval(address from, uint256 tokens, address token, bytes data) public;
}

contract OToken is StandardToken{
    
    // log when unspent approval is revoked
    event RevokeApproval(address indexed _owner, address indexed _spender);
    
    // constructor of contract.
    constructor() public{
        symbol = "O";
        name = "OToken";
        decimals = 18;
        _totalSupply = 2500000000 * 10**uint(decimals);  // 2.5 billion tokens
        balances[owner] = _totalSupply;  // give owner all supply
        emit Transfer(address(0), owner, _totalSupply);  // log event
    }
    
    // function used to revoke any unspent approval
    function revokeApproval(address _spender) public returns(bool) {
        require(allowed[msg.sender][_spender] > 0);
        allowed[msg.sender][_spender] = 0;
        emit RevokeApproval(msg.sender, _spender);
        
    }
    
    // ------------------------------------------------------------------------
    // Token owner can approve for `spender` to transferFrom(...) `tokens`
    // from the token owner's account. The `spender` contract function
    // `receiveApproval(...)` is then executed
    // ------------------------------------------------------------------------
    function approveAndCall(address _spender, uint _value, bytes _data) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        ApproveAndCallFallBack(_spender).receiveApproval(msg.sender, _value, address(this), _data);
        return true;
    }
    
    
    // ------------------------------------------------------------------------
    // Don't accept ETH
    // ------------------------------------------------------------------------
    function () public payable {
        revert();
    }
    
    // ------------------------------------------------------------------------
    // Owner can transfer out any accidentally sent ERC20 tokens
    // ------------------------------------------------------------------------
    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }
    
    
}
