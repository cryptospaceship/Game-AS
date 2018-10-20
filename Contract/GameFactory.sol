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
    address admin;
    bool gameReady;
    uint gameLaunch;
    uint gamePlayValue;
    uint endBlock;
    uint players;


    using AddressUtils for address;


    function getGame()
        external
        view
        returns(string name, uint launch, uint reward, uint playvalue)
    {
        name = "Juego";
        launch = gameLaunch;
        reward = address(this).balance;
        playvalue = gamePlayValue;
    }


    function getGame2() 
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

    event WinnerEvent(
        address winner,
        uint reward
    );

    function claimVictory()
        external
        isGameReady
    {
        require(candidate != address(0) && endBlock <= block.number && endBlock != 0);
        winner = candidate;
        endBlock = 0;
        gameReady = false;

        emit WinnerEvent(
            winner,
            address(this).balance
        );
        candidate.transfer(address(this).balance);
    }


    function setGameAttributes(address _shipContract, uint _startAt, uint mapSideSize)
        external
        onlyOwner
    {
        setSpaceShipContract(_shipContract);
        if (_startAt == 0)
            gameLaunch = block.number;
        else
            gameLaunch = _startAt;

        require(mapSideSize <= 64);

        changeMapSize(mapSideSize);
        
        gameReady = true;
        gamePlayValue = 0.1 ether;
    }

    function setSpaceShipContract(address _address)
        internal
    {
        require(_address.isContract());
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

