pragma solidity 0.4.25;

import "./Mortal.sol";
import "./AddressUtils.sol";
import "./SpaceShipInterface.sol";
import "./GameSpacialPort.sol";

contract GameFactory is Mortal, GameSpacialPort {

    SpaceShipInterface spaceShipInterface;
    address spaceShipContract;
    address candidate;
    address winner;
    bool gameReady;
    bool gameEnd;
    uint gameLaunch;
    uint shipWinner;
    uint gamePlayValue;
    uint endBlock;
    uint players;

    function getGame() 
        external
        view
        returns(
            bool _gameReady, 
            uint _gameLaunch,
            uint _gamePlayValue,
            uint _endBlock,
            uint _reward,
            uint _players,
            address _candidate,
            address _winner
        )
    {
        _gameReady = gameReady;
        _candidate = candidate;
        _winner = winner;
        _gameLaunch = gameLaunch;
        _gamePlayValue = gamePlayValue;
        _endBlock = endBlock;
        _reward = address(this).balance;
        _players = players;
    }

    modifier isGameReady() {
        require(gameReady);
        _;
    }

    modifier isGameStart() {
        require(isGameStarted());
        _;
    }

    modifier onlySpaceShipContract() {
        require(msg.sender == spaceShipContract);
        _;
    }

    function setGameAttributes(address _shipContract, uint _startAt)
        external
        onlyOwner
    {
        require(gameEnd == false);
        setSpaceShipContract(_shipContract);
        if (_startAt == 0)
            gameLaunch = block.number;
        else
            gameLaunch = _startAt;
        
        gameEnd = false;
        gameReady = true;
        gamePlayValue = 0.00001 ether;
    }

    function setSpaceShipContract(address _address)
        internal
    {
        require(AddressUtils.isContract(_address));
        /**
         TODO: Check if a valid contract, maybe using ERC165
         */
        spaceShipContract = _address; 
        spaceShipInterface = SpaceShipInterface(_address);
    }

    function isGameStarted() 
        internal
        view
        returns(bool)
    {
        return (gameReady && block.number >= gameLaunch);
    }
}

