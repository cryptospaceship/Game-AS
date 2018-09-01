pragma solidity 0.4.24;

import "./GameSpacialPort.sol";
import "./GameLib.sol";
import "./GameShipResources.sol";
import "./GameFactory.sol";
import "./UtilsLib.sol";


contract GameShipFactory_linked is GameFactory, GameSpacialPort {

    struct FleetDesign {
        uint fleetType;
        uint attack;
        uint defense;
        uint distance;
        uint load;
    }
    
    struct FleetCost {
        uint energy;
        uint graphene;
        uint metal;
    }
    
    struct Fleet {
        FleetDesign fleetDesign;
        FleetCost fleetCost;
        uint fleetSize;
        uint fleetInProduction;
        uint fleetEndProduction;
        bool fleetDesigned;
    }

    struct Lock {
        uint move;
        uint mode;
        uint resource;
        uint building;
        uint fleet;
        uint fireCannon;
    }

    struct Warehouse {
        uint energy;
        uint graphene;
        uint metal;
    }

    struct Buildings {
        uint warehouseLevel;
        uint hangarLevel;
        uint cannonLevel;
    }

    struct Resources {
        uint[12] energyPanelLevel;
        uint grapheneCollectorLevel;
        uint metalCollectorLevel;
    }

    struct GameSpaceShip {
        string shipName;
        address owner;
        uint x;
        uint y;
        uint[3] resourceDensity;
        uint mode;
        uint lastHarvest;
        Fleet fleet;
        Resources resources;
        Buildings buildings;
        Warehouse warehouse;
        Lock lock;
        uint damage;
        bool inPort;
        bool isPortDefender;
    }


    event AttackShipEvent(
        uint _from,
        uint _to,
        uint _attacker_size,
        uint _defender_size,
        uint _attacker_left,
        uint _defender_left,
        uint _e,
        uint _g,
        uint _m
    );

    event AttackPortEvent(
        uint _from,
        uint _attacker_size,
        uint _attacker_left,
        uint[4] _to,
        uint[5] _defenders_size,
        uint[5] _defenders_left
    );

    event PortConquestEvent(
        address owner,
        uint _from
    );

    event FireCannonEvent(
        uint _from,
        uint _to,
        uint _damage,
        bool _destroyed
    );

    event SentResourcesEvent(
        uint _from,
        uint _to,
        uint _e,
        uint _g,
        uint _m
    );



    mapping ( address => bool ) playing;
    mapping ( address => uint ) ownerToShip;
    mapping ( uint => GameSpaceShip ) shipsInGame;
    mapping ( uint => bool ) isShipInGame;

    /*
     * Listado de los Ids
     */
    uint[] shipsId;

    /*
     * Cantidad de Naves en Juego
     */
    uint shipsPlaying;

    constructor() public {
        shipsPlaying = 0;
    }


    function placeShip(uint _ship)
        external
        payable
        isGameReady
    {
        bool inGame;
        require(!isShipInGame[_ship]);
        GameSpaceShip storage gss = shipsInGame[_ship];
        (gss.shipName,,inGame,gss.owner,,,,,) = spaceShipInterface.getShip(_ship);
        
        require(inGame == false);

        require(msg.sender == gss.owner);

        require(playing[gss.owner] == false);

        require(spaceShipInterface.setGame(_ship));

        /**
         * Init wharehouse Stock
         */
        (gss.warehouse.energy,gss.warehouse.graphene,gss.warehouse.metal) = GameLib.getInitialWarehouse();

        /**
         * Init Ownership
         */
        playing[gss.owner] = true;
        ownerToShip[gss.owner] = _ship;

        /**
         * Init Ship Locks
         */
        gss.lastHarvest = gameLaunch;
        gss.lock.move = gameLaunch;
        gss.lock.mode = gameLaunch;
        gss.lock.resource = gameLaunch;
        gss.lock.building = gameLaunch;
        gss.lock.fleet = gameLaunch;
        gss.lock.fireCannon = gameLaunch;
        isShipInGame[_ship] = true;

        /**
         * Place Ship in Map
         */
        gss.x = uint(keccak256(gss.shipName,block.number)) % 64;
        gss.y = uint(keccak256(block.number,gss.shipName)) % 64;
        setInMapPosition(_ship,gss.x,gss.y);
        (gss.resourceDensity[0],gss.resourceDensity[1],gss.resourceDensity[2]) = getResourceDensity(gss.x,gss.y);
        
        shipsPlaying = shipsPlaying + 1;
        shipsId.push(_ship);
    }



    /*
     * Esta funcion es solamente durante la etapa de desarrollo
     */
    function adminSetShipVars(uint _ship, uint x, uint y, uint[12] pLevel, uint[2] rLevel, uint[3] bLevel, uint[3] stock)
        external
        onlyOwnerOrAdmin
    {
        GameSpaceShip storage ship = shipsInGame[_ship];
        uint b = block.number;

        require(isShipInGame[_ship]);

        unsetInMapPosition(ship.x,s.y);
        ship.lastHarvest = b;
        setInMapPosition(_ship,x,y);
        ship.resources.energyPanelLevel = pLevel;
        ship.resources.grapheneCollectorLevel = rLeve[0];
        ship.resources.metalCollectorLevel = rLevel[1];
        ship.buildings.warehouseLevel = bLevel[0];
        ship.buildings.hangarLevel = bLevel[1];
        ship.buildings.cannonLevel = bLevel[2];
        ship.warehouse.energy = stock[0];
        ship.warehouse.graphene = stock[1];
        ship.warehouse.metal = stock[2];
    }



    function unplaceShip(uint _ship)
        external
        onlySpaceShipContract
        isGameReady
        returns(bool)
    {
        address owner = shipsInGame[_ship].owner;
        require(isShipInGame[_ship]);
        unsetInMapPosition(shipsInGame[_ship].x,shipsInGame[_ship].y);
        playing[owner] = false;
        delete(ownerToShip[owner]);
        delete(shipsInGame[_ship]);
        isShipInGame[_ship] = false;
        return true;
    }

    /*------------------------------------------------------------------------------
     *                          Function Modifiers
     *
     *------------------------------------------------------------------------------
     */
    modifier upgradeResourceUnlocked(uint _ship) {
        uint lock_resource = shipsInGame[_ship].lock.resource;
        require(
            lock_resource <= block.number
        );
        _;
    }

    modifier upgradeBuildingUnlocked(uint _ship) {
        uint lock_building = shipsInGame[_ship].lock.building;
        require( 
            lock_building <= block.number
        );
        _;
    }

    modifier movemmentUnlocked(uint _ship) {
        uint lock_move = shipsInGame[_ship].lock.move;
        require(
            lock_move <= block.number
        );
        _;
    }

    modifier changeModeUnlocked(uint _ship) {
        uint lock_changeMode = shipsInGame[_ship].lock.mode;
        require(
            lock_changeMode <= block.number
        );
        _;
    }

    modifier fleetReady(uint _ship) {
        uint lock_fleet = shipsInGame[_ship].lock.fleet;
        require(
            lock_fleet <= block.number
        );
        _;
    }


    modifier onlyWithFleet(uint _ship) {
        require(
            getFleetSize(_ship) > 0
        );
        _;
    }

    modifier onlyShipOwner(uint _ship) {
        bool owner = (msg.sender == shipsInGame[_ship].owner);
        require(
            isShipInGame[_ship] && owner
        );
        _;
    }

    modifier onlyWithCannon(uint _ship) {
        uint cannonLevel = shipsInGame[_ship].buildings.cannonLevel;
        require(
            cannonLevel >= 1
        );
        _;
    }

    modifier cannonReady(uint _ship) {
        uint lock_cannon = shipsInGame[_ship].lock.fireCannon;
        require(
            lock_cannon <= block.number
        );
        _;
    }

    modifier onlyWithHangar(uint _ship) {
        uint hangarLevel = shipsInGame[_ship].buildings.hangarLevel;
        require(
            hangarLevel >= 1
        );
        _;
    }

    modifier notInPort(uint _ship) {
        require(
            shipsInGame[_ship].inPort == false
        );
        _;
    }

    modifier onlyIfCanBuildFleet(uint _ship) {
        require(
            canBuildFleet(_ship)
        );
        _;
    }

    
    modifier validResourceType(uint _type, uint _index) {
        require(
            _type <= 2 && _index <= 11
        );
        _;
    }

    modifier validBuildingType(uint _type) {
        require(
            _type <= 2
        );
        _;
    }

    modifier validMode(uint _mode) {
        require(
            _mode <= 3
        );
        _;
    }

    modifier validMoveMode(uint _ship) {
        require(      
            shipsInGame[_ship].mode != 3
        );
        _;
    }


    function attackShip(uint _from, uint _to)
        external
        isGameStart
        onlyShipOwner(_from)
        onlyWithFleet(_from)
        fleetReady(_from)
        notInPort(_to)
        notInPort(_from)
    {
        attackShipInternal(_from,_to);
    }


    function attackPort(uint _from, uint _port)
        external
        isGameStart
        onlyShipOwner(_from)
        onlyWithFleet(_from)
        fleetReady(_from)
        notInPort(_from)
        validPortId(_port)
    {
        attackPortInternal(_from);
    }


    function fireCannon(uint _from, uint _to)
        external
        isGameStart
        onlyShipOwner(_from)
        onlyWithCannon(_from)
        cannonReady(_from)
        notInPort(_from)
        notInPort(_to)
    {

        fireCannonInternal(_from,_to);
    }

    function sendResources(uint _from, uint _to, uint energy, uint graphene, uint metal)
        external
        isGameStart
        onlyShipOwner(_from)
        onlyWithFleet(_from)
        fleetReady(_from)
        notInPort(_from)
        notInPort(_to)
    {
        sendResourcesInternal(_from,_to,energy,graphene,metal);
    }


    function upgradeBuilding(uint _ship, uint _type)
        external
        isGameStart
        onlyShipOwner(_ship)
        upgradeBuildingUnlocked(_ship)
        validBuildingType(_type)
    {
        upgradeBuildingInternal(_ship,_type);
    }

    function upgradeResource(uint _ship, uint _type, uint _index)
        external
        isGameStart
        onlyShipOwner(_ship)
        upgradeResourceUnlocked(_ship)
        validResourceType(_type,_index)
    {
        upgradeResourceInternal(_ship,_type,_index);
    }

    function sendResourcesInternal(uint _from, uint _to, uint energy, uint graphene, uint metal)
        internal
    {
        GameSpaceShip storage to = shipsInGame[_to];
        GameSpaceShip storage from = shipsInGame[_from];
        uint load = getFleetLoad(_from);
        uint lock;
        bool inRange;

        require(load >= energy && load >= graphene && load >= metal);

        (inRange,lock) = GameLib.checkFleetRange(
            getShipDistance(_from,_to), 
            getFleetRange(_from),
            from.mode, 
            from.damage,
            false
        );

        require(inRange);

        expend(_from,energy,graphene,metal);
        from.lock.fleet = lock;
        _addWarehouse(to.warehouse, energy, graphene, metal, to.buildings.warehouseLevel);

        emit SentResourcesEvent(_from,_to,energy,graphene,metal);
    }

    function designFleet(uint _ship, uint _attack, uint _defense, uint _distance, uint _load)
        external
        isGameStart
        onlyShipOwner(_ship)
        onlyWithHangar(_ship)
    {
        GameSpaceShip storage ship = shipsInGame[_ship];
        uint e;
        uint g;
        uint m;
        uint fleetType;

        require(canDesignFleet(_ship));
        (fleetType,e,g,m) = GameLib.getFleetCost(_attack,_defense,_distance,_load); 
        require(fleetType != 0);
        ship.fleet.fleetDesigned = true;
        
        ship.fleet.fleetCost.energy = e;
        ship.fleet.fleetCost.graphene = g;
        ship.fleet.fleetCost.metal = m;
        ship.fleet.fleetDesign.fleetType = fleetType;
        ship.fleet.fleetDesign.attack = _attack;
        ship.fleet.fleetDesign.defense = _defense;
        ship.fleet.fleetDesign.distance = _distance;
        ship.fleet.fleetDesign.load = _load;
    }

    function buildFleet(uint _ship, uint size)
        external
        isGameStart
        onlyShipOwner(_ship)
        onlyWithHangar(_ship)
        onlyIfCanBuildFleet(_ship)
    {
        FleetCost storage ac = shipsInGame[_ship].fleet.fleetCost;    
        uint energyProduction;

        (energyProduction,,) = getProductionPerBlock(_ship);
        require(size <= energyProduction);
        expend(_ship,ac.energy*size,ac.graphene*size,ac.metal*size);
        addFleetToProduction(_ship,size);
    }


    function moveTo(uint _ship, uint x, uint y)
        external
        isGameStart
        onlyShipOwner(_ship)
        movemmentUnlocked(_ship)
        validMoveMode(_ship)
    {
        GameSpaceShip storage ship = shipsInGame[_ship];
        bool inRange;
        uint lock;

        (inRange, lock) = GameLib.checkRange(
            getDistanceTo(_ship,x,y), 
            ship.mode, 
            ship.damage
        );
    
        require(inRange);
        ship.lock.move = lock;
        collectResourcesAndSub(_ship,0,0,0);
        if (ship.inPort) {
            ship.inPort = false;
            if (ship.isPortDefender) {
                unsetShipInDefense(_ship);
                ship.isPortDefender = false;
            }
        }                
        else {
            unsetInMapPosition(ship.x,ship.y);
        }
        setInMapPosition(_ship,x,y);
        ship.x = x;
        ship.y = y;
        (ship.resourceDensity[0],ship.resourceDensity[1],ship.resourceDensity[2]) = getResourceDensity(x,y);
    }    

    /**
     * Considerar la idea de hacer dos funciones:
     * 1- lantTo(): Para aterrizar en un planeta
     * 2- fortifyTo(): Para defender un planeta
     */
    function landTo(uint _ship, uint x, uint y, bool defense)
        external
        isGameStart
        onlyShipOwner(_ship)
        movemmentUnlocked(_ship)
        validMoveMode(_ship)
    {
        GameSpaceShip storage ship = shipsInGame[_ship];
        bool inRange;
        uint lock;
        require(isValidPort(getMapPosition(x,y))); 
        
        (inRange,lock) = GameLib.checkRange(getPortDistance(_ship),ship.mode, ship.damage);
        require(inRange);

        ship.lock.move = lock;
        collectResourcesAndSub(_ship,0,0,0);
        unsetInMapPosition(ship.x,ship.y);
        ship.inPort = true;
        if (defense == true) {
            require(getFleetSize(_ship) > 0);
            setShipInDefense(_ship);
            ship.isPortDefender = true;
        }
        ship.x = x;
        ship.y = y;
        ship.resourceDensity[1] = 0;
        ship.resourceDensity[2] = 0;
    }

    function changeMode(uint _ship, uint _mode) 
        external
        isGameStart
        onlyShipOwner(_ship)
        changeModeUnlocked(_ship)
        validMode(_mode)
    {
        shipsInGame[_ship].lock.mode = GameLib.lockChangeMode(shipsInGame[_ship].damage);
        expend(_ship,2000,0,0);
        shipsInGame[_ship].mode = _mode;
    }

    function upgradeBuildingInternal(uint _ship, uint _type)
        internal
    {
        uint energy;
        uint graphene;
        uint metal;
        uint lock;
        uint level = _getBuildingLevelByType(shipsInGame[_ship].buildings, _type) + 1;
        require(level <= 4);
        (energy,graphene,metal,lock) = GameLib.getUpgradeBuildingCost(_type,level,shipsInGame[_ship].damage);
        shipsInGame[_ship].lock.building = lock;
        expend(_ship,energy,graphene,metal);
        _addBuildingLevel(shipsInGame[_ship].buildings,_type);
    }

    function upgradeResourceInternal(uint _ship, uint _type, uint _index)
        internal
    {
        GameSpaceShip storage s = shipsInGame[_ship];
        uint energy;
        uint graphene;
        uint metal;
        uint lock;
        uint level = _getResourceLevelByType(s.resources, _type, _index) + 1;
        
        require(level <= 10);
        (energy,graphene,metal,lock) = GameLib.getUpgradeResourceCost(_type,level,s.damage);

        s.lock.resource = lock;
        collectResourcesAndSub(_ship,energy,graphene,metal);
        _addResourceLevel(s.resources,_type,_index);
    }

    /*
     * Version 1.3-AS Se cambia el nombre a disassembleFleet.
     * Se corrigio el bug de los requerimientos para destruirla
     */
    function disassembleFleet(uint _ship)
        external
        isGameStart
        onlyShipOwner(_ship)
    {
        GameSpaceShip storage ship = shipsInGame[_ship];

        require(
            getFleetSize(_ship) > 0 && 
            (ship.fleet.fleetInProduction == 0 || ship.fleet.fleetEndProduction <= block.number )
        );            
        setFleetSize(_ship,0);
    }

    function getShipByOwner(address owner)
        external
        view
        returns(bool,uint)
    {
        return (playing[owner],ownerToShip[owner]);
    }

    function getShipsId()
        external
        view
        returns (uint[] ids)
    {
        ids = new uint[](shipsPlaying);
        uint i;
        uint j;
        j = 0;
        for ( i = 0; i < shipsId.length ; i++ ) {
            if (isShipInGame[shipsId[i]]) {
                ids[j] = shipsId[i];
                j = j + 1;
            }
        }
    }

    function viewShip(uint _ship)
        external
        view
        returns
        (
            string shipName,
            uint x,
            uint y,
            uint mode,
            uint damage
        )
    {
        shipName = shipsInGame[_ship].shipName;
        x = shipsInGame[_ship].x;
        y = shipsInGame[_ship].y;
        mode = shipsInGame[_ship].mode;
        damage = shipsInGame[_ship].damage;
    }

    function viewBuildingLevel(uint _ship)
        external
        view
        returns
        (
            uint warehouse,
            uint hangar,
            uint cannon
        )
    {
        hangar = shipsInGame[_ship].buildings.hangarLevel;
        warehouse = shipsInGame[_ship].buildings.warehouseLevel;
        cannon = shipsInGame[_ship].buildings.cannonLevel;
    }


    function viewResourceProduction(uint _ship)
        external
        view
        returns
        (
            uint energy,
            uint graphene,
            uint metal,
            uint[12] memory energyLevel,
            uint grapheneCollectorLevel,
            uint metalCollectorLevel
        )
    {
        (energy,graphene,metal) = getProductionPerBlock(_ship);
        (energyLevel,grapheneCollectorLevel,metalCollectorLevel) = _getResourceLevel(shipsInGame[_ship].resources);
    }

    function viewShipVars(uint _ship)
        external
        view
        returns
        (
            uint energyStock,
            uint grapheneStock,
            uint metalStock,
            // Agregar Nivel de Warehouse
            uint countdownToUpgradeResources,
            uint countdownToUpgradeBuildings,
            uint countdownToMove,
            uint countdownToFleet,
            uint countdownToMode,
            uint countdownToFireCannon
        )
    {
        uint b = block.number;
        GameSpaceShip storage ship = shipsInGame[_ship];
        (energyStock,grapheneStock,metalStock) = getResources(_ship);
        if (b > ship.lock.resource) 
            countdownToUpgradeResources = 0;
        else
            countdownToUpgradeResources = ship.lock.resource - b;

        if (b > ship.lock.building) 
            countdownToUpgradeBuildings = 0;
        else
            countdownToUpgradeBuildings = ship.lock.building - b;

        if (b > ship.lock.move) 
            countdownToMove = 0;
        else
            countdownToMove = ship.lock.move - b;

        if (b > ship.lock.mode)
            countdownToMode = 0;
        else
            countdownToMode = ship.lock.mode - b;
        
        if (b > ship.lock.fleet)
            countdownToFleet = 0;
        else
            countdownToFleet = ship.lock.fleet - b;

        if (b > ship.lock.fireCannon)
            countdownToFireCannon = 0;
        else
            countdownToFireCannon = ship.lock.fireCannon - b;
    }

    function viewFleet(uint _ship)
        external
        view
        returns
        (
            uint fleetType,
            uint energyCost,
            uint grapheneCost,
            uint metalCost,
            uint attack,
            uint defense,
            uint distance,
            uint load,
            uint size,
            uint inProduction,
            uint endProduction,
            uint blocksToEndProduction
        )
    {
        GameSpaceShip storage ship = shipsInGame[_ship];
        fleetType = ship.fleet.fleetDesign.fleetType;
        energyCost = ship.fleet.fleetCost.energy;
        grapheneCost = ship.fleet.fleetCost.graphene;
        metalCost = ship.fleet.fleetCost.metal;
        attack = ship.fleet.fleetDesign.attack;
        defense = ship.fleet.fleetDesign.defense;
        distance = ship.fleet.fleetDesign.distance;
        load = ship.fleet.fleetDesign.load;
        endProduction = ship.fleet.fleetEndProduction;
        if (endProduction <= block.number) {
            size = ship.fleet.fleetSize + ship.fleet.fleetInProduction;
            inProduction = 0;
            blocksToEndProduction = 0;
        }
        else {
            size = ship.fleet.fleetSize;
            inProduction = ship.fleet.fleetInProduction;
            blocksToEndProduction = endProduction - block.number;
        }
    }


    function fireCannonInternal(uint _from,uint _to)
        internal
    {
        GameSpaceShip storage from = shipsInGame[_from];
        GameSpaceShip storage to = shipsInGame[_to];
        bool inRange;
        uint cost;
        uint lock;
        uint damage;
        /*
         * Trae la distancia
         */
        require(from.mode == 2);

        (inRange,damage,cost,lock) = GameLib.checkCannonRange(
            getShipDistance(_from,_to),
            from.buildings.cannonLevel,
            from.damage
        );

        require(inRange);

        expend(_from,cost,0,0);
        from.lock.fireCannon = lock;

        if (to.damage + damage >= 100) {
            destroyShip(_to);
            emit FireCannonEvent(_from,_to,100,true);
        }
        else {
            collectResourcesAndSub(_to, 0,0,0);
            to.damage = to.damage + damage;
            emit FireCannonEvent(_from,_to,to.damage,false);
        }
    }


    function attackPortInternal(uint _from)
        internal
    {
        uint aRemain;
        uint lock;
        bool combat;
        uint[5] memory dRemain;
        uint[5] memory attacker;

        (attacker[0],attacker[1]) = getFleetAttack(_from);
        attacker[2] = getFleetRange(_from);
        attacker[3] = shipsInGame[_from].mode;
        attacker[4] = shipsInGame[_from].damage;

        (combat,aRemain,dRemain,lock) = portCombat(
            attacker,
            getPortDistance(_from)
        );

        require(combat);

        shipsInGame[_from].lock.fleet = lock;

        attackPortResult(_from,aRemain,dRemain);
    }


    function attackPortResult(uint _from, uint aRemain, uint[5] dRemain)
        internal
    {
        uint aSize;
        uint[5] memory dSize;
        uint ship;
        uint i;

        aSize = getFleetSize(_from);
        (,dSize) = getPortDefend();

        emit AttackPortEvent(
            _from,
            aSize,
            aRemain,
            spacialPort.defenses,
            dSize,
            dRemain
        );

        if (aRemain > 0) {
            /*
             * BUG: Si el que conquistaba el puerto era el mismo
             * dueño, se reiniciaba el contador
             */
            if (spacialPort.owner != shipsInGame[_from].owner) {
                candidate = shipsInGame[_from].owner;
                endBlock = block.number + GameLib.getBlocksToWin();
            }

            // La posicion defensiva del planeta
            spacialPort.fleetSize = 0;

            // La cantidad de defensores
            spacialPort.shipsInDefenses = 0;

            for (i = 0; i <= 3; i++ ) {
                ship = spacialPort.defenses[i];
                /*
                 * Elimina la posicion de defensa
                 */
                spacialPort.defenses[i] = 0;
                shipsInGame[ship].isPortDefender = false;
                setFleetSize(ship,0);
            }

            emit PortConquestEvent(
                candidate,
                _from
            );

        } else {
            spacialPort.fleetSize = dRemain[0];
            for (i = 1; i <= 4; i++ ) {
                ship = spacialPort.defenses[i-1];
                if (dRemain[i] == 0) {
                    /*
                     * Elimina la posicion de defensa
                     */
                    spacialPort.defenses[i-1] = 0;
                    shipsInGame[ship].isPortDefender = false;
                    setFleetSize(ship,0);
                }
                setFleetSize(ship,dRemain[i]);
            }
        }
        setFleetSize(_from,aRemain);
    }


    function portCombat(uint[5] attacker, uint distance)
        internal
        view
        returns(bool, uint, uint[5], uint)
    {
        uint[5] memory dSize;
        uint[5] memory dPoints;
                
        (dPoints,dSize) = getPortDefend();

        return GameLib.portCombatCalc(
            attacker,
            dPoints,
            dSize,            
            distance
        );
    }
        

    function attackShipInternal(uint _from, uint _to)
        internal
    {
        uint aRemain;
        uint dRemain;
        uint lock;
        bool combat;

        (combat,aRemain,dRemain,lock) = shipCombat(_from,_to, getShipDistance(_from, _to));
        require(combat);
        shipsInGame[_from].lock.fleet = lock;
        return attackShipResult(_from,_to,aRemain,dRemain);
    }


    function shipCombat(uint _from, uint _to, uint distance)
        internal
        view
        returns(bool, uint, uint, uint)
    {
        uint[5] memory attacker;
        uint[3] memory defender;

        (attacker[0],attacker[1]) = getFleetAttack(_from);
        (defender[0],defender[1]) = getFleetDefend(_to);
        attacker[2] = getFleetRange(_from);
        attacker[3] = shipsInGame[_from].mode;
        attacker[4] = shipsInGame[_from].damage; 
        defender[2] = shipsInGame[_to].mode;

        return GameLib.shipCombatCalc(
            attacker,    // Attacker Points
            defender,
            distance
        );
    }

    function attackShipResult(uint _from, uint _to, uint aRemain, uint dRemain)
        internal
    {
        uint e;
        uint g;
        uint m;
        uint aSize;
        uint dSize;

        if (aRemain > 0) {
            (e,g,m) = toSack(_to,shipsInGame[_from].fleet.fleetDesign.load * aRemain);
            _addWarehouse(shipsInGame[_from].warehouse,e,g,m,shipsInGame[_from].buildings.warehouseLevel);
        }
        else {
            e = 0;
            g = 0;
            m = 0;
        }
        aSize = getFleetSize(_from);
        dSize = getFleetSize(_to);

        setFleetSize(_from,aRemain);
        setFleetSize(_to,dRemain);
        emit AttackShipEvent(_from,_to,aSize,dSize,aRemain,dRemain,e,g,m);
    }


    function _setWarehouse(Warehouse storage w, uint e, uint g, uint m)
        internal
    {
        w.energy = e;
        w.graphene = g;
        w.metal = m;
    }

    function _addWarehouse(Warehouse storage w, uint e, uint g, uint m, uint level)
        internal 
    {
        uint load = GameLib.getWarehouseLoadByLevel(level);
        if (w.energy + e > load)
            w.energy = load;
        else
            w.energy += e;

        if (w.graphene + g > load)
            w.graphene = load;
        else
            w.graphene += g;
        
        if (w.metal + m > load)
            w.metal = load;
        else 
            w.metal += m;
    }
    
    function _subWarehouse (Warehouse storage w, uint e, uint g, uint m) 
        internal 
    {
        require(w.energy >= e && w.graphene >= g && w.metal >= m);
        w.energy -= e;
        w.graphene -= g;
        w.metal -= m;
    }


    

    function destroyShip(uint _ship)
        internal
    {
        address owner = shipsInGame[_ship].owner;
        playing[owner] = false;
        unsetInMapPosition(shipsInGame[_ship].x,shipsInGame[_ship].y);
        delete(ownerToShip[owner]);
        delete(shipsInGame[_ship]);
        isShipInGame[_ship] = false;
        require(spaceShipInterface.throwShip(_ship));
    }

    function expend(uint _ship, uint energy, uint graphene, uint metal)
        internal
    {
        collectResourcesAndSub(_ship,energy,graphene,metal);
    }

    function toSack(uint _ship, uint load) 
        internal
        returns(uint e, uint g, uint m)
    {
        uint energy;
        uint graphene;
        uint metals;

        (energy, graphene, metals) = getResources(_ship);
        if ( load > energy ) 
            e = energy;
        else
            e = load;
        if ( load > graphene )
            g = graphene;
        else
            g = load;
        if ( load > metals )
            m = metals;
        else
            m = load;

        expend(_ship,e,g,m);    
    }

    function collectResourcesAndSub(uint _ship, uint e, uint g, uint m)
        internal
    {
        GameSpaceShip storage s = shipsInGame[_ship];
        uint energy;
        uint graphene;
        uint metal;

        (energy, graphene, metal) = getResources(_ship);
        require(
            s.lastHarvest <= block.number && 
            energy >= e && graphene >= g && metal >= m    
        );    // Pensar Mejor esta linea
        s.lastHarvest = block.number;   
        energy -= e;
        graphene -= g;
        metal -= m;
        _setWarehouse(s.warehouse,energy,graphene,metal);
    }


    function addFleetToProduction(uint _ship, uint size)
        internal
        returns(bool, uint)
    {
        Fleet storage a = shipsInGame[_ship].fleet;
        bool build;
        uint end;

        if (a.fleetInProduction > 0)
            a.fleetSize = a.fleetSize + a.fleetInProduction;

        
        (build, end) = GameLib.getFleetEndProduction(
            size,
            getFleetSize(_ship),
            shipsInGame[_ship].buildings.hangarLevel,
            shipsInGame[_ship].damage
        );
        require(build);
        a.fleetInProduction = size;
        a.fleetEndProduction = end;
    }

    function inWarehouse(uint _ship, uint e, uint g, uint m)
        internal
        view
        returns(bool)
    {
        GameSpaceShip storage s = shipsInGame[_ship];
        return (s.warehouse.energy >= e && s.warehouse.graphene >= g && s.warehouse.metal >= m);
    }

    function warehouseFull(uint _ship)
        internal
        view
        returns(bool)
    {
        GameSpaceShip storage s = shipsInGame[_ship];
        uint maxStorage = getWarehouseLoad(_ship);
        return (s.warehouse.energy == maxStorage || s.warehouse.graphene == maxStorage || s.warehouse.metal == maxStorage);
    }

    function getResources(uint _ship)
        internal
        view
        returns(uint energy, uint graphene, uint metal)    
    {
        (energy,graphene,metal) = getUnharvestResources(_ship);
        uint maxLoad = getWarehouseLoad(_ship);
        energy = energy + shipsInGame[_ship].warehouse.energy;
        if (energy > maxLoad) 
            energy = maxLoad;

        graphene = graphene + shipsInGame[_ship].warehouse.graphene;
        if (graphene > maxLoad)
            graphene = maxLoad;
        
        metal = metal + shipsInGame[_ship].warehouse.metal;
        if (metal > maxLoad)
            metal = maxLoad;
    }

    function getWarehouseLoad(uint _ship)
        internal
        view
        returns(uint load)
    {
        load = GameLib.getWarehouseLoadByLevel(shipsInGame[_ship].buildings.warehouseLevel); 
    }

    function getUnharvestResources(uint _ship)
        internal
        view
        returns(uint energy, uint graphene, uint metal)
    {
        uint blocks = block.number - shipsInGame[_ship].lastHarvest;
        (energy,graphene,metal) = getProductionPerBlock(_ship);
        energy = energy * blocks;
        graphene = graphene * blocks;
        metal = metal * blocks;
    }

    function getProductionPerBlock(uint _ship)
        internal
        view
        returns(uint energy, uint graphene, uint metal)
    {
        GameSpaceShip storage ship = shipsInGame[_ship];

        if (!isGameStarted() || !isShipInGame[_ship]) {
            energy = 0;
            graphene = 0;
            metal = 0;
        }
        else {
            (energy,graphene,metal) = GameLib.getProduction(
                ship.resources.energyPanelLevel,
                ship.resources.grapheneCollectorLevel,
                ship.resources.metalCollectorLevel,
                [0,ship.resourceDensity[1], ship.resourceDensity[2]],
                ship.damage
            );
            energy = energy - getFleetConsumption(_ship);
        }
    }

    function getShipPosition(uint _ship)
        internal
        view
        returns(uint[2])
    {
        GameSpaceShip storage ship = shipsInGame[_ship];
        return [ship.x,ship.y];
    }
    
    function getShipPosition(GameSpaceShip storage ship)
        internal
        view
        returns(uint[2])
    {
        return [ship.x,ship.y];
    }

    function getShipDistance(uint _from, uint _to)
        internal
        view
        returns(uint)
    {
        return Utils.getDistance(getShipPosition(_from),getShipPosition(_to));
    }

    function getPortDistance(uint _from)
        internal
        view
        returns(uint)
    {
        return Utils.getDistance(getShipPosition(_from),[spacialPort.x,spacialPort.y]);   
    }

    function getDistanceTo(uint _from, uint x, uint y)
        internal
        view
        returns(uint)
    {
        return Utils.getDistance(getShipPosition(_from),[x,y]);
    }


    function getFleetConsumption(uint _ship)
        internal
        view
        returns(uint)
    {
        Fleet storage a = shipsInGame[_ship].fleet;
        return a.fleetSize + a.fleetInProduction;
    }

    function getFleetRange(GameSpaceShip storage ship)
        internal
        view
        returns(uint)
    {
        return ship.fleet.fleetDesign.distance;
    }

    function getFleetRange(uint _ship)
        internal
        view
        returns(uint)
    {
        Fleet storage a = shipsInGame[_ship].fleet;
        return a.fleetDesign.distance;
    }


    function getFleetSize(uint _ship)
        internal
        view
        returns(uint)
    {
        Fleet storage a = shipsInGame[_ship].fleet;
        if (a.fleetEndProduction <= block.number)
            return a.fleetSize + a.fleetInProduction;
        return a.fleetSize;
    }

    
    function getFleetSize(GameSpaceShip storage ship)
        internal
        view
        returns(uint)
    {
        if (ship.fleet.fleetEndProduction <= block.number)
            return ship.fleet.fleetSize + ship.fleet.fleetInProduction;
        return ship.fleet.fleetSize;
    }

    function getFleetLoad(uint _ship)
        internal
        view
        returns(uint)
    {
        Fleet storage a = shipsInGame[_ship].fleet;
        return getFleetSize(_ship) * a.fleetDesign.load;
    }

    function setFleetSize(uint _ship, uint size)
        internal
    {
        Fleet storage a = shipsInGame[_ship].fleet;
        if (a.fleetEndProduction <= block.number && a.fleetInProduction > 0)
            a.fleetInProduction = 0;
        a.fleetSize = size;    
    }

    function getFleetAttack(uint _ship)
        internal
        view
        returns(uint, uint)
    {
        Fleet storage a = shipsInGame[_ship].fleet;
        return (a.fleetDesign.attack,getFleetSize(_ship));
    }

    function getFleetAttack(GameSpaceShip storage ship)
        internal
        view
        returns(uint, uint)
    {
        return (ship.fleet.fleetDesign.attack,getFleetSize(ship));
    }

    function getPortDefend()
        internal
        view
        returns(uint[5] dPoints, uint[5] dSize)
    {
        uint i;
        uint ship;
        dPoints[0] = spacialPort.fleetDefense;
        dSize[0] = spacialPort.fleetSize;
        for ( i = 1; i <= 4; i++ ) {
            ship = spacialPort.defenses[i-1];
            if (ship >= 1000) {
                (dPoints[i],dSize[i]) = getFleetDefend(ship);
            }
        }
    }


    function getFleetDefend(uint _ship)
        internal
        view
        returns(uint, uint)
    {
        Fleet storage a = shipsInGame[_ship].fleet;
        return (a.fleetDesign.defense,getFleetSize(_ship));
    }

    function getFleetDefend(GameSpaceShip storage ship)
        internal
        view
        returns(uint, uint)
    {
        return (ship.fleet.fleetDesign.defense,getFleetSize(ship));
    }

    function canDesignFleet(uint _ship) 
        internal
        view
        returns(bool)
    {
        GameSpaceShip storage ship = shipsInGame[_ship];
        return 
        ( 
            ship.fleet.fleetDesigned == false || ( ship.fleet.fleetSize == 0 && (ship.fleet.fleetInProduction == 0 || ship.fleet.fleetEndProduction <= block.number ))
        );
    }

    function canBuildFleet(uint _ship)
        internal
        view
        returns(bool)
    {
        GameSpaceShip storage ship = shipsInGame[_ship];
        return (ship.fleet.fleetDesigned && ship.fleet.fleetEndProduction <= block.number);
    }


    function _getResourceLevel (Resources storage r) 
        internal 
        view 
        returns(uint[12],uint,uint) 
    {
        return
        (
            r.energyPanelLevel,
            r.grapheneCollectorLevel,
            r.metalCollectorLevel
        );
    }
    
    function _getResourceLevelByType( Resources storage r, uint _type, uint _index)
        internal
        view
        returns(uint)
    {
        if (_type == 0) {
            return r.energyPanelLevel[_index];
        }
        if (_type == 1) {
            return r.grapheneCollectorLevel;
        }
        if (_type == 2) {
            return r.metalCollectorLevel;
        }
        return 0;
    }

    function _addResourceLevel (Resources storage r, uint _type, uint _index) 
        internal 
    {
        if (_type == 0) {
            r.energyPanelLevel[_index]++;
            return;
        }
        if (_type == 1) { 
            r.grapheneCollectorLevel++;
            return;
        }
        if (_type == 2) { 
            r.metalCollectorLevel++;
            return;
        }
    }


    function _getBuildingLevelByType( Buildings storage b, uint _type)
        internal
        view
        returns(uint)
    {
        if (_type == 0) {
            return b.warehouseLevel;
        }
        if (_type == 1) {
            return b.hangarLevel;
        }
        if (_type == 2) {
            return b.cannonLevel;
        }
        return 0;
    }
    
    function _addBuildingLevel (Buildings storage b, uint _type)
        internal 
    {
        if (_type == 0) {
            b.warehouseLevel++;
            return;
        }
        if (_type == 1) { 
            b.hangarLevel++;
            return;
        }
        if (_type == 2) { 
            b.cannonLevel++;
            return;
        }
    }
}