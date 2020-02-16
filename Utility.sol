pragma solidity ^0.4.16;

/// Utility methods
contract MyUtility {
    /// @notice Compare two strings to see if they match
    /// @dev Solidity requires us to hash our strings (w/ keccak256) before comparing them
    /// @param _a & _b are strings to compare
    /// @return True if strings are equal, false if not
    function compareStrings(string _a, string _b) public pure returns (bool) {
        return keccak256(_a) == keccak256(_b);
    }

    /// @notice Compare two addresses to see if they match
    /// @dev Solidity requires us to hash our addresses (w/ keccak256) before comparing them
    /// @param _a & _b are addresses to compare
    /// @return True if addresses are equal, false if not
    function compareAddresses(address _a, address _b) public pure returns (bool) {
        return keccak256(_a) == keccak256(_b);
    }

    /// @notice Compare target date is within start and end
    /// @param _start & _end are the date range
    /// @param _target is the compare date
    /// @return True if in range, false if not
    function compareDateRange(uint256 _start, uint256 _end, uint _target) public pure returns (bool) {
        return _start <= _target && _end >= _target;
    }
}
