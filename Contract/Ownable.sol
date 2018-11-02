pragma solidity ^0.4.23;

contract Ownable {
    address owner;
	/**
	 * @dev The Ownable constructor sets the original `owner` of the contract to the sender
	 * account.
	 */
    constructor() public {
        owner = msg.sender;
    }

	/**
	 * @dev Throws if called by any account other than the owner.
	 */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
}
