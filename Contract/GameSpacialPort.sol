pragma solidity 0.4.25;

import "./GameShipMap.sol";

contract GameSpacialPort is GameShipMap {
    
    struct SpacialPort {
        string name;
        address owner; 
        uint[4] defenses; // Defenses places
        uint shipsInDefenses;
        uint x;
        uint y;
        uint fleetSize;
        uint fleetDefense;
    }

    /**
     * This contract Version only have 1 Spacial Port
     */
    SpacialPort spacialPort;

    modifier validPortId(uint _port) {
        require(isValidPort(_port));
        _;
    }

    function createSpacialPort(string name, uint x, uint y, uint fleetSize, uint fleetDefense) 
        external
        onlyOwner
    {
        setInMapPosition(1,x,y);
        spacialPort.name = name;
        spacialPort.x = x;
        spacialPort.y = y;
        spacialPort.fleetSize = fleetSize;
        spacialPort.fleetDefense = fleetDefense;
    }

    function getPort()
        external
        view
        returns(
            string name,
            address owner,
            uint[4] shipDefenders,
            uint portDefendPower
        )
    {
        name = spacialPort.name;
        owner = spacialPort.owner;
        shipDefenders = spacialPort.defenses;
        portDefendPower = spacialPort.fleetDefense * spacialPort.fleetSize;
    }

    function setShipInDefense(uint _ship)
        internal
    {
        require(spacialPort.shipsInDefenses < 4);
        uint i;
        for ( i = 0; i < 4; i++ ) {
            if (spacialPort.defenses[i] == 0)  {
                spacialPort.defenses[i] = _ship;
                spacialPort.shipsInDefenses++;
                return;
            }
        }   
    }

    function unsetShipInDefense(uint _ship) 
        internal
    {
        uint i;
        for ( i = 0; i < 4; i++ ) {
            if (spacialPort.defenses[i] == _ship)  {
                spacialPort.defenses[i] = 0;
                spacialPort.shipsInDefenses--;
                return;
            }
        } 
    }

    function isValidPort(uint _port) 
        internal
        pure
        returns(bool)
    {
        return (_port == 1 );
    }
}