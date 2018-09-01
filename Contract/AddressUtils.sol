pragma solidity ^0.4.23;

library AddressUtils {
    function isContract(address _address) 
        internal 
        view 
        returns (bool) 
    {
        uint256 size;
        assembly { size := extcodesize(_address) }
        return size > 0;
    }
}