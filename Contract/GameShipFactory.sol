pragma solidity 0.4.25;

import "./GameLib.sol";
import "./GameFactory.sol";
import "./GameEvents.sol";

contract GameShipFactory is GameFactory, GameEvents {

    struct FleetConfig {
        uint attack;
        uint defense;
        uint distance;
        uint load;
    }
    
    struct Fleet {
        FleetConfig fleetConfig;
        uint fleetSize;
        uint fleetInProduction;
        uint fleetEndProduction;
    }

    struct Lock {
        uint move;
        uint mode;
        uint fleet;
        uint wopr;
    }

    struct Warehouse {
        uint energy;
        uint graphene;
        uint metal;
    }

    struct Buildings {
        uint[4] level;
        uint endUpgrade;
        /*
         * Roles:
         * 1 - Cannon
         * 2 - Converter
         * 3 - Reparer
         */
        uint role;
    }

    struct Resources {
        /**
         * 0: Upgrading
         * 1 - 6: Energy
         * 7: Graphene
         * 8: Metal
         */
        uint[9] level;
        uint endUpgrade;
        uint gConverter;
        uint mConverter;
    }

    struct GameSpaceShip {
        string shipName;
        address owner;
        uint x;
        uint y;
        uint[3] resourceDensity;
        uint[6] qaim;
        uint mode;
        uint lastHarvest;
        Fleet fleet;
        Resources resources;
        Buildings buildings;
        Warehouse warehouse;
        Lock lock;
        uint damage;
        uint points;
        uint takedowns;
        bool inPort;
        bool isPortDefender;
        bool destroyed;
    }


    mapping ( address => bool ) playing;
    mapping ( address => uint ) ownerToShip;
    mapping ( uint => GameSpaceShip ) shipsInGame;
    mapping ( uint => bool ) isShipInGame;

    /*
     * Listado de los Ids
     */
    uint[] shipsId;

    function getShipPoints(uint _ship)
        public
        view
        returns(uint)
    {
        GameSpaceShip storage s = shipsInGame[_ship];
        return s.points + s.takedowns/100;
    }

    function placeShip(uint _ship, uint qaim_0, uint qaim_1)
        external
        payable
        isGameReady
    {
        bool inGame;
        GameSpaceShip storage gss = shipsInGame[_ship];

        require(
            gamePlayValue == msg.value && 
            isShipInGame[_ship] == false &&
            qaim_0 < 6 && qaim_1 < 6
        );

        /*
        0    address owner,
        1    string name,
        2    uint color,
        3    uint gen,
        4    uint points,
        5    uint level,
        6    uint plays,
        7    uint wins,
        8    uint launch,
        9    uint progress,
        10   uint qaims,
        11   bool inGame
        */
        (gss.owner,gss.shipName,,,,,,,,,,inGame) = spaceShipInterface.getShip(_ship);
        
        require(
            inGame == false &&
            msg.sender == gss.owner && 
            playing[gss.owner] == false
        );
        
        spaceShipInterface.setGame(_ship);

        gss.qaim[qaim_0] = spaceShipInterface.getQAIM(_ship,qaim_0);
        gss.qaim[qaim_1] = spaceShipInterface.getQAIM(_ship,qaim_1);

        /**
         * Init Ownership
         */
        playing[gss.owner] = true;
        ownerToShip[gss.owner] = _ship;

        /**
         * Init Ship Locks
         */
        isShipInGame[_ship] = true;

        
        gss.lastHarvest = gameLaunch;
        gss.lock.move = gameLaunch;
        gss.lock.mode = gameLaunch;
        gss.resources.endUpgrade = gameLaunch;
        gss.buildings.endUpgrade = gameLaunch;
        gss.lock.fleet = gameLaunch;
        gss.lock.wopr = gameLaunch;
        setInitialValues(gss);
        /**
         * Place Ship in Map
         */

        setInMapPosition(_ship,gss.x,gss.y);
        
        addUniqueId(_ship);
        players = players + 1;
        changeMapSize(players);
        emit ShipStartPlayEvent(_ship,block.number);
    }

    function addUniqueId(uint id) internal {
        uint i;
        for ( i = 0; i < shipsId.length; i++) {
            if (shipsId[i] == id)
                return;
        }
        shipsId.push(id);
    }

    function removeShip(uint _ship)
        external
        onlySpaceShipContract
        returns(bool, uint)
    {
        address owner = shipsInGame[_ship].owner;
        uint points = getShipPoints(_ship);
        bool win = (ownerToShip[winner] == _ship);

        require((gameEnd == true || gameReady == true) && isShipInGame[_ship]);

        unsetInMapPosition(shipsInGame[_ship].x,shipsInGame[_ship].y);
        playing[owner] = false;
        delete(ownerToShip[owner]);
        delete(shipsInGame[_ship]);
        isShipInGame[_ship] = false;
        players = players - 1;

        emit ShipEndPlayEvent(_ship,block.number);
        return (win,points);
    }

    function setInitialValues(GameSpaceShip storage gss)
        internal
    {
        Warehouse storage w = gss.warehouse;
        uint stock;

        (gss.x, gss.y, stock, gss.resourceDensity) = GameLib.getInitialValues(gss.shipName,sideSize,entropy);

        // Borrar a partir de aca
        gss.buildings.level[1] = 4;
        w.energy = 1600000;//stock;
        w.graphene = 1600000;//stock;
        w.metal = 1600000;//stock;
    }

}
