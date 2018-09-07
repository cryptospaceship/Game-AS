pragma solidity 0.4.24;

import "./GameSpacialPort.sol";
import "./GameLib.sol";
import "./GameFactory.sol";
import "./UtilsLib.sol";


contract GameShipFactory_linked is GameFactory, GameSpacialPort {


    struct Resources {
        /**
         * 0: Upgrading
         * 1 - 6: Energy
         * 7: Graphene
         * 8: Metal
         */
        uint[9] level;
        uint endUpgrade;    
    }

    struct resource {
        uint8 index;
        uint8 panel_1;
        uint8 panel_2;
        uint8 panel_3;
        uint8 panel_4;
        uint8 panel_5;
        uint8 panel_6;
        uint8 graphene;
        uint8 metal;
        uint8 __res;
        uint8 gDensity;
        uint8 mDensity;
        uint32 eStock;
        uint32 gStock;
        uint32 mStock;
        uint34 endUpgrade;
        uint34 lastHarvest;
    }

    struct Res {
        bytes9 level;
        bytes3 density;
        uint32 eStock;
        uint32 gStock;
        uint32 mStock;
        uint32 endUpgrade;
        uint32 lastHarvest;
    }


    function commitResources(Res storage stg, bytes9 level, bytes3 density, uint32 eStock, uint32 gStock, uint32 mStock, uint32 endUpdate, uint32, lastHarvest)
        internal
    {
        stg.level = level;
        stg.density = density;
        stg.eStock = eStock;
        stg.mStock = mStock;
        stg.endUpdate = endUpdate;
        stg.lastHarvest = lastHarvest;
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


    modifier upgradeResourceFinish(uint _ship) {
        uint end = shipsInGame[_ship].resources.endUpgrade;
        require(
            end <= block.number
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


    
    modifier validResourceType(uint _type, uint _index) {
        require(
            _type <= 2 && _index <= 5
        );
        _;
    }

 
    function upgradeResource(uint _ship, uint _type, uint _index)
        external
        isGameStart
        onlyShipOwner(_ship)
        upgradeResourceFinish(_ship)
        validResourceType(_type,_index)
    {
        upgradeResourceInternal(_ship,_type,_index);
    }


    function upgradeResourceInternal(uint _ship, uint _type, uint _index)
        internal
    {
        GameSpaceShip storage s = shipsInGame[_ship];
        uint energy;
        uint graphene;
        uint metal;
        uint end;
        uint level = getResourceLevelByType(s.resources, _type, _index) + 1;
        
        require(level <= 10);
        (energy,graphene,metal,end) = GameLib.getUpgradeResourceCost(_type,level,s.damage);

        collectResourcesAndSub(_ship,energy,graphene,metal);
        s.resources.endUpgrade = end;
        addResourceLevel(s.resources,_type,_index);
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
        load = GameLib.getWarehouseLoadByLevel(getWarehouseLevel(_ship)); 
    }

    function getUnharvestResources(uint _ship)
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
            (energy,graphene,metal) = GameLib.getUnharvestResources(
                ship.resources.level, 
                ship.resources.endUpgrade, 
                ship.resourceDensity, 
                getFleetConsumption(_ship),
                ship.damage, 
                ship.lastHarvest
            );
        }
    }

    function getResourceLevel (Resources storage resource) 
        internal 
        view 
        returns(uint[6] e, uint g, uint m) 
    {
        uint i;
        for ( i = 0; i < 6; i++ ) 
            e[i] = resource.level[i+1];
            
        g = resource.level[uint(GameLib.ResourceIndex.GRAPHENE)];
        m = resource.level[uint(GameLib.ResourceIndex.METAL)];

        if (block.number < resource.endUpgrade) {
            i = resource.level[uint(GameLib.ResourceIndex.INDEX_UPGRADING)];
            if ( i == uint(GameLib.ResourceIndex.GRAPHENE) ) {
                g--;
                return;
            }
            if ( i == uint(GameLib.ResourceIndex.METAL) ) {
                m--;
                return;
            }
            e[i-1]--;
        }

    }



    function getWarehouseLevel(uint _ship)
        internal
        view
        returns(uint)
    {
        return getBuildingLevelByType(shipsInGame[_ship].buildings,0);
    }


    function getResourceLevelByType( Resources storage resource, uint _type, uint _index)
        internal
        view
        returns(uint)
    {
        uint[6] memory e;
        uint g;
        uint m;

        (e,g,m) = getResourceLevel(resource);

        if (_type == 0) 
            return e[_index];
        if (_type == 1) 
            return g;
        if (_type == 2) 
            return m;
    }

    function addResourceLevel (Resources storage resource, uint _type, uint _index) 
        internal 
    {
        if (_type == 0) {
            resource.level[_index+1]++;
            resource.level[uint(GameLib.ResourceIndex.INDEX_UPGRADING)] = _index+1;
            return;
        }
        if (_type == 1) {
            resource.level[uint(GameLib.ResourceIndex.GRAPHENE)]++; 
            resource.level[uint(GameLib.ResourceIndex.INDEX_UPGRADING)] = uint(GameLib.ResourceIndex.GRAPHENE);
            return;
        }
        if (_type == 2) { 
            resource.level[uint(GameLib.ResourceIndex.METAL)]++; 
            resource.level[uint(GameLib.ResourceIndex.INDEX_UPGRADING)] = uint(GameLib.ResourceIndex.METAL);
            return;
        }
    }
}