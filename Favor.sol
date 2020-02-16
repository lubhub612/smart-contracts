pragma solidity ^0.4.16;

import "./Token.sol";

/// @title Favor Exchange
/// @notice This smart contract enables exchanging favors for tokens
/// @dev Be sure to pass the Token.sol address when deplying this contract
contract FavorExchange {
    address tokenContractAddress;
    MyAdvancedToken Token;

    constructor(address tokenContract) public {
        tokenContractAddress = tokenContract;
        Token = MyAdvancedToken(tokenContractAddress);
    }

    struct Favor {
        uint favorId;
        string status;
        // Statuses: Pending -> New -> In Progress -> Complete -> Acknowledged
        uint reward;
        string name;
        string description;
        address postedByAddress;
    }

    uint private favorId = 0;
    // favors is an array of Favor structs
    Favor[] private favors;
    // Array of assignee addresses are mapped to a favor's ID
    mapping(uint => address[]) private favorAssignees;
    // Array of bidder addresses are mapped to a favor's ID
    mapping(uint => address[]) private favorBidders;
    // Escrow is our 'balance' to hold and dispense favor rewards
    uint public escrow;

    event FavorEmitted(uint favorId);

    /// @notice Post a favor
    /// @param _reward The amount of tokens to reward upon completion
    /// @param _description A description of the favor's requirements
    /// @return Returns true if successful, false if not
    function postFavor(uint _reward, string _description, string _name) public returns (uint thisFavorId) {
        var newFavor = Favor({
            favorId : favorId,
            status : "Pending",
            reward : _reward,
            name : _name,
            description : _description,
            postedByAddress : msg.sender
            });
        favorId++;
        favors.push(newFavor);
        transferToEscrow(_reward);
        emit FavorEmitted(favorId - 1);
        return favorId - 1;
    }

    /// @notice Approve an favor by change its status from Pending to New
    /// @param _favorId The favor's ID
    /// @return Returns true if successful, false if not
    function approveFavor( uint _favorId) public returns (bool) {
        require(compareStrings(favors[_favorId].status, "Pending"), "Only pending favor can be approved.");
        require(compareAddresses(msg.sender, Token.owner()), "Only admin can approve favor.");
        favors[_favorId].status = "Open";
        emit FavorEmitted(_favorId);
        return true;
    }

    /// @notice Reject an favor by change its status from Pending to rejected
    /// @param _favorId The favor's ID
    /// @return Returns true if successful, false if not
    function rejectFavor( uint _favorId) public returns (bool) {
        require(compareStrings(favors[_favorId].status, "Pending"), "Only pending favor can be rejected.");
        require(compareAddresses(msg.sender, Token.owner()), "Only admin can reject favor.");
        favors[_favorId].status = "Rejected";
        transferFromEscrow(favors[_favorId].postedByAddress, favors[_favorId].reward);
        emit FavorEmitted(_favorId);
        return true;
    }

    /// @notice Return a favor's data
    /// @param _favorId The ID of the favor to return
    /// @return Returns all data on the chain for a specific favor
    function getFavor(uint _favorId) public view returns (uint myId, string status, uint reward, string name, string description, address postedByAddress, address[] assignees) {
        return
        (
        favors[_favorId].favorId,
        favors[_favorId].status,
        favors[_favorId].reward,
        favors[_favorId].name,
        favors[_favorId].description,
        favors[_favorId].postedByAddress,
        favorAssignees[_favorId]
        );
    }

    /// @notice Return a favor's bidders data
    /// @param _favorId The ID of the favor to return
    /// @return Returns all bidders on the chain for a specific favor
    function getBidders(uint _favorId) public view returns (address[] bidders) {
        return
        (
        favorBidders[_favorId]
        );
    }

    /// @notice Mark a favor as completed so that submitter can acknowledge its completion
    /// @param _favorId The ID of the favor to mark as completed
    /// @return Returns true if successful
    function completeFavor(uint _favorId) public returns (uint _thisFavorId) {
        require(compareStrings(favors[_favorId].status, "In Progress"), "Favors can be marked complete only if they are currently in progress.");
        require(compareManyAddresses(msg.sender, favorAssignees[_favorId]), "Only favor assignees can complete favor.");
        favors[_favorId].status = "Completed";
        emit FavorEmitted(_favorId);
        return _favorId;
    }

    function revertCompleteFavor(uint _favorId) public returns (uint _thisFavorId) {
        require(compareManyAddresses(msg.sender, favorAssignees[_favorId]) || compareAddresses(msg.sender, favors[_favorId].postedByAddress), "Only favor assignees or favor submitter can revert a completed favor");
        favors[_favorId].status = "In Progress";
        emit FavorEmitted(_favorId);
        return _favorId;
    }

    /// @notice Mark a favor as acknowledged and transfer the reward to the assignee
    /// @param _favorId The ID of the favor to mark as acknowledged
    /// @param _assignees the array of all assignees.
    /// @param _rewards the array of rewards for assignees who mapping to _assignees array.
    /// @return Returns true if successful
    function acknowledgeFavor(uint _favorId, address[] _assignees, uint[] _rewards) public returns (uint _thisFavorId) {
        require(compareStrings(favors[_favorId].status, "Completed"), "Favor must be completed to acknowledge its completion.");
        require(compareAddresses(favors[_favorId].postedByAddress, msg.sender), "Only favor poster can acknowledge completion.");
        require((_assignees.length == _rewards.length), "Invalid data.");

        for(uint i = 0; i < _assignees.length; i++){
            transferFromEscrow(_assignees[i], _rewards[i]);
        }

        favors[_favorId].status = "Acknowledged";
        emit FavorEmitted(_favorId);
        return _favorId;
    }

    /// @notice Cancel a favor and returns its reward to the favor's submitter
    /// @param _favorId The ID of the favor to cancel
    /// @return Returns true if successful, false if not
    function cancelFavor(uint _favorId) public returns (uint _thisFavorId) {
        require(compareAddresses(favors[_favorId].postedByAddress, msg.sender) || compareAddresses(msg.sender, Token.owner()), "Error: Only admin or submitter can cancel favor.");
        favors[_favorId].status = "Cancelled";
        transferFromEscrow(favors[_favorId].postedByAddress, favors[_favorId].reward);
        emit FavorEmitted(_favorId);
        return _favorId;
    }

    /// @notice Set favorAssignees to an inputted array of addresses
    /// @param _favorId The id of favor to which you'll assign the assignees
    /// @param _assigneeAddresses Array of assignee addresses
    /// @return Returns favorId if successful
    function addAssignee(uint _favorId, address[] _assigneeAddresses) public returns (uint _thisFavorId) {
        require(compareAddresses(favors[_favorId].postedByAddress, msg.sender), "Only favor's poster can assign users to favor.");
        favorAssignees[_favorId] = _assigneeAddresses;
        favors[_favorId].status = "In Progress";
        emit FavorEmitted(_favorId);
        return _favorId;
    }

    /// @notice As an employee, bid to complete a favor
    /// @param _favorId The favor the bidder would like to work on
    /// @return True if successful
    function bid(uint _favorId) public returns (uint _thisFavorId) {
        favorBidders[_favorId].push(msg.sender);
        emit FavorEmitted(_favorId);
        return _favorId;
    }

    /// @notice Transfer a favor's reward from user to escrow
    /// @param _amount The amount to tranfser to receiver
    /// @dev This will fail unless we call approve to Token contract before this function
    /// @return Returns true if successful, false if not
    function transferToEscrow(uint _amount) internal returns (bool success) {
        Token.transferFrom(msg.sender, address(this), _amount);
        escrow += _amount;
        return true;
    }

    /// @notice Transfer a favor's reward from escrow to user
    /// @param _receiver Address to receive the reward from escrow
    /// @param _amount The amount to tranfser to receiver
    /// @dev Note that we must approve a transaction before transferring w/ Token contract
    /// @return Returns true if successful, false if not
    function transferFromEscrow(address _receiver, uint _amount) internal returns (bool success) {
        Token.transfer(_receiver, _amount);
        escrow -= _amount;
        return true;
    }

    /// @notice Count a favor's assignees
    /// @return Returns a uint representing the count of assignees a favor has
    function countAssignees(uint _favorId) internal view returns (uint assigneeCount) {
        return favorAssignees[_favorId].length;
    }

    /// @notice Count a favor's bidders
    /// @return Returns a uint representing the count of bidders a favor has
    function countBidders(uint _favorId) internal view returns (uint bidderCount) {
        return favorBidders[_favorId].length;
    }

    /// @notice Compare two strings to see if they match
    /// @dev Solidity requires us to hash our strings (w/ keccak256) before comparing them
    /// @param _a & _b are strings to compare
    /// @return True if strings are equal, false if not
    function compareStrings(string _a, string _b) internal pure returns (bool) {
        return keccak256(_a) == keccak256(_b);
    }

    /// @notice Compare two addresses to see if they match
    /// @dev Solidity requires us to hash our addresses (w/ keccak256) before comparing them
    /// @param _a & _b are addresses to compare
    /// @return True if addresses are equal, false if not
    function compareAddresses(address _a, address _b) internal pure returns (bool) {
        return keccak256(_a) == keccak256(_b);
    }

    function compareManyAddresses(address _addressToCompare, address[] _addresses) internal pure returns (bool) {
        for (var i = 0; i < _addresses.length; i++) {
            if (_addresses[i] == _addressToCompare) {
                return true;
            }
        }
        return false;
    }
}
