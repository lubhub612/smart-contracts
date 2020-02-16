pragma solidity ^0.4.16;

/// @title owned contract allows us to set an owner for the contract and restrict functions to an owner
/// @notice Only the owner can assign another owner
/// @notice The original owner is whoever deploys the contract
contract owned {
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Error: Sender is not owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        owner = newOwner;
    }
}

/// @title EthFaucet allow admin to provide ether to users
/// @notice Ethereum serves no other purpose in our private network
/// @dev Owner/admin should call this contract on behalf of users that need ether
contract EthFaucet is owned {

    event ContractEmptied(address indexed emptiedBy);
    event FallbackFunctionFired();
    event TransferEther(address indexed requestedBy);

    uint256 public balance;

    /// @notice This is a fallback function, which fires when a user calls an invalid function, or if a
    /// user sends ether to the contract without calling a function.
    /// @dev This is what we use to "fill up" the contract's balance
    function() public payable {
        balance += msg.value;
        emit FallbackFunctionFired();
    }

    /// @notice Owner can empty all ether from the contract
    /// @return Returns true if sucessful, false if not
    function emptyContract() public onlyOwner returns (bool success) {
        require(address(this).balance > 0, "Error: Insufficient Contract Balance");
        require(msg.sender == owner, "Error: Only owner can empty contract.");
        msg.sender.transfer(balance);
        balance = 0;
        emit ContractEmptied(msg.sender);
        return true;
    }

    /// @notice This function will transfer ether to a user
    /// @param _transferTo The address to which ether will be transferred
    /// @return Returns true if successful, false if not
    function getEth(address _transferTo) public returns (bool success) {
        require(address(this).balance > 1000000000000000000, "Error: Insufficient Contract Balance");
        _transferTo.transfer(1000000000000000000);
        balance -= 1000000000000000000;
        emit TransferEther(msg.sender);
        return true;
    }
}
