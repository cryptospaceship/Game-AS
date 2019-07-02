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
    uint balance;

    /**
     * Increase reward
     */
    function () external payable {}

    /*
     * Agregar
     *  - shipWinner
     *  - si el juego termino
     */
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
            address _winner,
            uint _shipWinner,
            bool _gameEnd
        )
    {
        _gameReady = gameReady;
        _candidate = candidate;
        _winner = winner;
        _gameLaunch = gameLaunch;
        _gamePlayValue = gamePlayValue;
        _endBlock = endBlock;
        if (gameEnd) {
            _reward = balance;
        } else {
            _reward = address(this).balance;
        }
        _players = players;
        _gameEnd = gameEnd;
        _shipWinner = shipWinner;
    }

    modifier isGamePlayable() {
        require(isPlayable());
        _;
    }

    modifier onlySpaceShipContract() {
        require(msg.sender == spaceShipContract);
        _;
    }

    function isPlayable() internal view returns(bool) {
        return (gameReady && block.number >= gameLaunch && gameEnd == false);
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
}

