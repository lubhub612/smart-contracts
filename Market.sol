pragma solidity ^0.4.16;

import "./Token.sol";

/// @title Market Exchange
/// @notice This smart contract enables post / approve / void / redeem / use of exchange items
/// @dev Be sure to pass the Token.sol's address when deploying this contract
contract MarketExchange {
    address tokenContractAddress;
    MyAdvancedToken Token;

    constructor(address tokenContract) public {
        tokenContractAddress = tokenContract;
        Token = MyAdvancedToken(tokenContractAddress);
    }

    struct MarketItem {
        uint itemId;
        string status; // Statuses: Pending -> Open, Void, Soldout
        uint unitPrice;
        string title;
        string description;
        address postedByAddress;
        uint availableUnit;
        uint counter;
        bool repeatable;
        // uint256 effDate;
        // uint256 expDate;
    }

    uint private itemId = 0;
    MarketItem[] private marketItems;
    mapping(uint => address[]) private itemRedeemAddresses;
    mapping(uint => string[]) private itemRedeemStatuses;
    // (itemId => (redeemed address => status "Redeem/Delivered/Confirmed/Void"   ))

    // Escrow is our 'balance' to hold and dispense redeem price
    uint public escrow;

    event ItemEmitted(uint itemId);

    /// @notice Post a new item
    /// @param _unitPrice The unit price of the item
    /// @param _title The name of the item
    /// @param _description A description of the item
    /// @param _availableUnit Maximum available unit, -1 unlimited
    /// @param _repeatable bulk redeem flag
    /// @return Returns true if successful, false if not
    function postItem(uint _unitPrice, string _title, string _description, uint _availableUnit, bool _repeatable) public returns (bool success) {
        MarketItem memory newItem = MarketItem({
            itemId : itemId,
            status : "Pending",
            unitPrice : _unitPrice,
            title : _title,
            description : _description,
            postedByAddress : msg.sender,
            availableUnit : _availableUnit,
            counter : 0,
            repeatable : _repeatable
            });

        marketItems.push(newItem);
        emit ItemEmitted(itemId);
        itemId++;
        return true;
    }

    /// @notice Return a item's data
    /// @param _itemId The ID of the item to return
    /// @return Returns all data on the chain for a specific item
    function getItem(uint _itemId) public view returns (uint myItemId, string status, uint unitPrice, string title, string description, uint availableUnit, uint counter, bool repeatable, address postedByAddress) {
        MarketItem storage item = marketItems[_itemId];
        return (
        item.itemId,
        item.status,
        item.unitPrice,
        item.title,
        item.description,
        item.availableUnit,
        item.counter,
        item.repeatable,
        item.postedByAddress
        );
    }

    /// @notice Approve an item by change its status from Pending to Open
    /// @param _itemId The item's ID
    /// @return Returns true if successful, false if not
    function approveItem(uint _itemId) public returns (bool) {
        MarketItem storage item = marketItems[_itemId];
        require(compareStrings(item.status, "Pending"), "Only pending item can be approved.");
        require(compareAddresses(msg.sender, Token.owner()), "Only admin can approve item.");
        item.status = "Open";
        emit ItemEmitted(_itemId);
        return true;
    }

    /// @notice Reject an item by change its status from Pending to Rejected
    /// @param _itemId The item's ID
    /// @return Returns true if successful, false if not
    function rejectItem(uint _itemId) public returns (bool) {
        MarketItem storage item = marketItems[_itemId];
        require(compareStrings(item.status, "Pending"), "Only pending item can be rejected.");
        require(compareAddresses(msg.sender, Token.owner()), "Only admin can reject item.");
        item.status = "Rejected";
        emit ItemEmitted(_itemId);
        return true;
    }

    /// @notice Redeem an item
    /// @param _itemId The ID of the item to redeem
    /// @return Returns true if successful
    function redeem(uint _itemId) public returns (bool) {
        MarketItem storage item = marketItems[_itemId];
        require(compareStrings(item.status, "Open"), "Only open item can be redeem.");
        require(!compareAddresses(item.postedByAddress, msg.sender), "Item owner cannot redeem.");
        /// TODO Date range checking.
        /// require(compareDateRange(item.effDate, item.expDate , now), "Item is not valid to be redeem.");
        require(item.availableUnit > item.counter, "Item out of stock");
        if (!item.repeatable) {
            require(!isRedeemed(_itemId, msg.sender), "Can only redeem once.");
        }

        itemRedeemAddresses[_itemId].push(msg.sender);
        itemRedeemStatuses[_itemId].push("Redeem");
        item.counter++;
        transferToEscrow(item.unitPrice);

        if (item.availableUnit == item.counter) {
            item.status = "Soldout";
        }
        emit ItemEmitted(_itemId);
        return true;
    }

    /// @notice Delivery an item by change its status from Redeem to Delivered
    /// @param _itemId The item's ID
    /// @param _account redeem's address
    /// @param _index position of redeem
    /// @return Returns true if successful, false if not
    function delivery(uint _itemId, address _account, uint _index) public returns (bool) {
        MarketItem storage item = marketItems[_itemId];

        require(compareAddresses(item.postedByAddress, msg.sender), "Only item owner can delivery.");
        require(compareAddresses(itemRedeemAddresses[_itemId][_index], _account), "Delivery to wrong person.");
        require(compareStrings(itemRedeemStatuses[_itemId][_index], "Redeem"), "Only redeemed item can be delivered.");

        itemRedeemStatuses[_itemId][_index] = "Delivered";

        emit ItemEmitted(_itemId);
        return true;
    }

    /// @notice Confirm an item by change its status from Delivered to Confirmed and payout money.
    /// @param _itemId The item's ID
    /// @param _account Redeem's address
    /// @param _index postion of redeems
    /// @return Returns true if successful, false if not
    function confirm(uint _itemId, address _account, uint _index) public returns (bool) {
        require(compareAddresses(msg.sender, Token.owner()) || (compareAddresses(msg.sender, _account) && compareAddresses(itemRedeemAddresses[_itemId][_index], _account)), "Only Admin or item redeem can confirm.");
        require(compareStrings(itemRedeemStatuses[_itemId][_index], "Delivered"), "Only delivered item can be confirmed.");

        itemRedeemStatuses[_itemId][_index] = "Confirmed";
        payout(_itemId);

        emit ItemEmitted(_itemId);
        return true;
    }

    /// @notice Void an item by change its status from Open to Void
    /// @param _itemId The item's ID
    /// @return Returns true if successful, false if not
    function voidPostedItem(uint _itemId) public returns (bool) {
        MarketItem storage item = marketItems[_itemId];
        require(!compareStrings(item.status, "Void"), "Voided item cannot be void.");
        require(compareAddresses(msg.sender, Token.owner()) || compareAddresses(msg.sender, item.postedByAddress), "Only admin or item owner can void item.");
        item.status = "Void";
        emit ItemEmitted(_itemId);
        return true;
    }

    /// @notice Void an item by change its status from Open to Void
    /// @param _itemId The item's ID
    /// @param _account Item's owner account
    /// @param _index position of index
    /// @return Returns true if successful, false if not
    function voidRedeemedItem(uint _itemId, address _account, uint _index) public returns (bool) {
        MarketItem storage item = marketItems[_itemId];
        require(compareAddresses(msg.sender, Token.owner()) || compareAddresses(itemRedeemAddresses[_itemId][_index], _account), "Only admin or item owner can void item.");
        require(!compareStrings(itemRedeemStatuses[_itemId][_index], "Delivered"), "Delivered item cannot be void.");

        itemRedeemStatuses[_itemId][_index] = "Void";
        item.counter--;
        if (compareStrings(item.status, "Soldout")) {
            item.status = "Open";
        }
        transferFromEscrow(msg.sender, item.unitPrice);
        emit ItemEmitted(_itemId);
        return true;
    }

    /// @notice return a redeem's data
    /// @param _itemId the item's ID
    /// @param _index the position of one redeem
    /// @return data of one redeem for a specified item
    function getRedeem(uint _itemId, uint _index) public view returns (address, string){
        return (
        itemRedeemAddresses[_itemId][_index],
        itemRedeemStatuses[_itemId][_index]
        );
    }

    /// @notice return all redeem address for one item.
    /// @param _itemId the item's ID
    /// @return address array that redeem specified item.
    function getRedeemAddresses(uint _itemId) public view returns (address[]){
        return (
        itemRedeemAddresses[_itemId]
        );
    }

    /// @notice return the status of specified postion redeem.
    /// @param _itemId the item's ID
    /// @param _index position of redeem
    /// @return status
    function getRedeemStatus(uint _itemId, uint _index) public view returns (string){
        return (
        itemRedeemStatuses[_itemId][_index]
        );
    }

    /// @notice check the address already redeemed or not.
    /// @param _itemId itemId, point out which address list.
    /// @param _address redeem address which will be checked.
    /// @return return true if already redeemed or false if not.
    function isRedeemed(uint _itemId, address _address) internal returns (bool){
        bool redeemed = false;
        uint size = itemRedeemAddresses[_itemId].length;
        for (uint i = 0; i < size; i++) {
            if (itemRedeemAddresses[_itemId][i] == _address) {
                redeemed = true;
                break;
            }
        }
        return redeemed;
    }


    /// @notice Payout all assignees equally
    /// @param _itemId The id of the favor to payout
    /// @return Returns true if successful, false if not
    function payout(uint _itemId) internal returns (bool) {
        MarketItem storage item = marketItems[_itemId];

        transferFromEscrow(item.postedByAddress, item.unitPrice);

        return true;
    }

    /// @notice Transfer token from redeem to escrow
    /// @param _amount The amount to tranfser to receiver
    /// @dev This will fail unless we call approve to Token contract before this function
    /// @return Returns true if successful, false if not
    function transferToEscrow(uint _amount) internal returns (bool success) {
        Token.transferFrom(msg.sender, address(this), _amount);
        escrow += _amount;
        return true;
    }

    /// @notice Transfer token from escrow to redeem
    /// @param _receiver redeem address to receive the token from escrow
    /// @param _amount The amount to tranfser to receiver
    /// @dev Note that we must approve a transaction before transferring w/ Token contract
    /// @return Returns true if successful, false if not
    function transferFromEscrow(address _receiver, uint _amount) internal returns (bool success) {
        Token.transfer(_receiver, _amount);
        escrow -= _amount;
        return true;
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

    /// @notice Compare target date is within start and end
    /// @param _start & _end are the date range
    /// @param _target is the compare date
    /// @return True if in range, false if not
    function compareDateRange(uint256 _start, uint256 _end, uint _target) internal pure returns (bool) {
        return _start <= _target && _end >= _target;
    }
}
