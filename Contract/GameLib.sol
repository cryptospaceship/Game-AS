pragma solidity 0.4.24;

library GameLib {

    /**
     * @dev checkRange(): Comprueba si la nave principal se puede mover determinada
     * distancia
     * @param distance Distancia de movimiento
     * @param mode Modo de la nave principal. -> 0, 1, 2, 3
     * @param damage Daño de la nave de 0 a 100
     * @return inRange Booleano para saber si la nave se puede mover
     * @return lock Cantidad de bloques para el proximo movimiento
     */
    function checkRange(uint distance, uint mode, uint damage)
        external
        view
        returns(bool inRange, uint lock)
    {
        inRange = (distance <= getMovemmentByMode(mode));
        if (inRange) 
            lock = lockMovemment(distance,mode,damage);
        else
            lock = 0;
    }

    /**
     * @dev checkCannonRange(): Comprueba si se puede disparar el cañon
     * @param distance Distancia de movimiento
     * @param level Nivel de cañon
     * @param shipDamage Daño de la nave principal
     * @return inRange: Si se puede disparar o no
     * @return damage: El daño que causa
     * @return cost: El costo de disparar el cañon
     * @return lock: Cantidad de de bloques para esperar el proximo disparo
     */
    function checkCannonRange(uint distance, uint level, uint shipDamage)
        external
        view
        returns(bool inRange, uint damage, uint cost, uint lock)
    {
        inRange = (level > 0 && (distance == 1 || (distance == 2 && level == 4)));
        if (inRange) {
            damage = getCannonDamage(level,distance);
            cost = getFireCannonCost();
            lock = block.number + 300; // Esto no me gusta
            if (shipDamage > 0) {
                lock = ((100 + shipDamage) * lock) / 100;
            }
        }
    }

    /**
     * @dev getProduction(): Calcula la produccion total de la nave
     * @param panels Array de 12 posiciones, con el nivel de cada panel
     * @param gCollector Nivel del colector de Graphene
     * @param mCollector Nivel del colector de metales
     * @param density Array de dos posisciones con la densidad de Graphene y Metal
     * @param damage Daño de la nave principal (Afecta la produccion)
     * @return energy: Produccion total de energia
     * @return graphene: Produccion total de graphene
     * @return metal: Produccion total de metales
     */
    function getProduction(uint[12] panels, uint gCollector, uint mCollector, uint[3] density, uint damage)
        external
        pure
        returns(uint energy, uint graphene, uint metal)
    {
        uint i;
        uint s;
        energy = 0;
        for (i = 0; i < 12; i++) {
            energy = energy + getProductionByLevel(panels[i]);
        }
        graphene = getProductionByLevel(gCollector) * density[1];
        metal = getProductionByLevel(mCollector) * density[2];

        if (damage != 0) {
            s = 100 - damage;
            energy = s * energy / 100;
            graphene = s * graphene / 100;
            metal = s * metal / 100;
        }
    }


    function portCombatCalc(uint[5] attacker, uint[5] dPoints, uint[5] dSize, uint distance)
        external
        view
        returns(bool combat, uint aRemain, uint[5] dRemain, uint lock)
    {
        (combat,lock) = checkFleetRange(distance, attacker[2], attacker[3], attacker[4],true);

        if (!combat)
            return;
        
        if (attacker[0] == 0) {
            aRemain = 0;
            dRemain = dSize;
            return;
        }

        (aRemain, dRemain) = portCombarCalcInternal(attacker[0],attacker[1],dPoints,dSize);
    }

    function shipCombatCalc(uint[5] attacker, uint[3] defender, uint distance)
        external
        view
        returns(bool combat, uint aRemain,uint dRemain, uint lock)  
    {
        (combat,lock) = checkFleetRange(distance, attacker[2], attacker[3], attacker[4], true);

        if (!combat)
            return;

        if (attacker[0] == 0) {
            aRemain = 0;
            dRemain = defender[1];
            return;
        }

        if ((defender[0] == 0 || defender[1] == 0) && (attacker[0] != 0 && attacker[1] != 0)) {
            aRemain = attacker[1];
            dRemain = 0;
            return;
        }

        (aRemain,dRemain) = shipCombatCalcInternal(attacker[0],attacker[1],attacker[3],defender[0],defender[1],defender[2]);
    }
    
    function getFleetEndProduction(uint size, uint actualSize, uint hangarLevel, uint damage)
        external
        view
        returns(bool,uint)
    {
        uint batches = (size/26) + 1;
        uint ret;
        ret = batches * (5-hangarLevel) * 80;
        if (damage > 0) {
            ret = ((100 + damage) * ret) / 100;
        }
        return ((size + actualSize <= hangarLevel * 100),(block.number + ret));
    }

    function getFleetCost(uint _attack, uint _defense, uint _distance, uint _load)
        external
        pure
        returns(
            uint fleetType,
            uint e, 
            uint g, 
            uint m
        ) 
    {
        uint points = _attack + _defense + (_distance * 7) + (_load/40);
        if ( points <= 100 && points != 0) {
            e = (20*_attack) + (20 * _defense) + (20*(_distance*7)) + (20*(_load/40));
            g = (70*_defense) + (70*(_distance*7)) + (50*_attack) + (30*(_load/40));
            m = (70*_attack) + (70*(_load/40)) + (50*_defense) + (30*(_distance*7));
            fleetType = getFleetType(_attack,_defense,_distance,_load);
        }
        else {
            e = 0;
            g = 0;
            m = 0;
            fleetType = 0;
        }
    }

    function lockChangeMode(uint damage) 
        external 
        view 
        returns(uint)
    {
        uint ret;
        ret = 280;
        if (damage > 0) {
            ret = ((100 + damage) * ret) / 100;
        }
        return block.number + ret;
    }

    function getWarehouseLoadByLevel(uint level)
        external
        pure
        returns(uint)
    {
        uint24[5] memory warehouseStorage = [10000, 50000, 150000, 1300000, 16000000];
        return warehouseStorage[level];
    }
    
    function getUpgradeBuildingCost(uint _type, uint _level, uint damage) 
        external 
        view 
        returns(uint energy, uint graphene, uint metal, uint lock)
    {
        uint24[5] memory buildingCost = [0,5292,23338,102910,453874];
        if (_type == 2) {
            energy = buildingCost[_level]*3;
            graphene = buildingCost[_level]*3;
            metal = buildingCost[_level]*3;
        } else {
            energy = buildingCost[_level];
            graphene = buildingCost[_level];
            metal = buildingCost[_level];
        }
        lock = lockUpgradeBuilding(_level,damage);
    }
    
    function getUpgradeResourceCost(uint _type, uint _level, uint damage) 
        external
        view
        returns(uint energy, uint graphene, uint metal, uint lock)
    {
        uint24[11] memory resourceCost = [0,1200,2520,5292,11113,23338,49009,102919,216131,453874,953136];
        if (_type == 0) {
            energy = resourceCost[_level]/2;
            graphene = resourceCost[_level];
            metal = resourceCost[_level];
        } else if (_type == 1) {
            energy = resourceCost[_level];
            graphene = resourceCost[_level]/2;
            metal = resourceCost[_level];
        } else if (_type == 2) {
            energy = resourceCost[_level];
            graphene = resourceCost[_level];
            metal = resourceCost[_level]/2;
        }
        lock = lockUpgradeResource(_level,damage);
    
    }

    function getBlocksToWin()
        external
        pure
        returns(uint)
    {
        return 20000;
    }

    function getInitialWarehouse()
        external
        pure 
        returns(uint, uint, uint)
    {
        return(10000,10000,10000);
    }
    
    function checkFleetRange(uint distance, uint fleetRange, uint mode, uint damage, bool battle)
        internal
        view
        returns(bool, uint)
    {
        uint distanceCanJump = fleetRange;
        uint lock;
        uint add;
        uint sub;
        bool inRange;

        (add,sub) = getDistanceBonusByMode(mode);
        if (add != 0) {
            distanceCanJump = distanceCanJump + (distanceCanJump * add / 100); 
        }
        if (sub != 0) {
            distanceCanJump = distanceCanJump - (distanceCanJump * sub / 100);
        }
        if (distanceCanJump >= distance) {
            inRange = true;
            lock = lockFleet(distance,battle,damage);
        }
        else
            inRange = false;

        return (inRange,lock);
    }


    function getFleetType(uint _attack, uint _defense, uint _distance, uint _load)
        internal
        pure
        returns(uint fleetType)
    {
        uint _d = _distance * 7;
        uint _l = _load/40;
        if ( _attack > _defense && _attack > _d && _attack > _l ) {
            fleetType = 1;
        }
        else {
            if (_defense > _attack && _defense > _d && _defense > _l) {
                fleetType = 2;
            }
            else {
                if ( _d > _attack && _d > _defense && _d > _l) {
                    fleetType = 3;
                }
                else {
                    if (_l > _attack && _l > _defense && _l > _d) {
                        fleetType = 4;
                    }
                    else {
                        fleetType = 5;
                    }
                }
            }
        }
    }

    function getCannonDamage(uint cannonLevel, uint distance)
        internal
        pure
        returns (uint)
    {
        return (cannonLevel * 5)/distance;
    }
    
    function getFireCannonCost()
        internal
        pure
        returns (uint)
    {
        return 2000000;
    }


    function portCombarCalcInternal(uint aPoints, uint aSize, uint[5] dPoints, uint[5] dSize)
        internal
        pure
        returns(uint aRemain, uint[5] dRemain)
    { 
        uint attackerPoints = aPoints * aSize;
        uint defenderPoints;
        uint p;
        uint i;
        uint s;

        for (i = 0; i <= 4; i++) 
            defenderPoints = defenderPoints + (dPoints[i] * dSize[i]);
        
        if (defenderPoints == 0)
            defenderPoints = 1;

        if (attackerPoints > defenderPoints) {
            // Gano el atacante
            s = 100-(100*defenderPoints/attackerPoints);
            if ( s != 0 ) {
                aRemain = s*aSize/100;
                if (aRemain == 0)
                    aRemain = 1;
            } else {
                aRemain = aSize;
            }
            for ( i = 0; i <= 4; i++ ) 
                dRemain[i] = 0;
        } else {
            // Gano el defensor
            s = defenderPoints - attackerPoints;
            aRemain = 0;
            for (i = 0; i <= 4; i++) {
                p = (dPoints[i] * dSize[i] * 100) / defenderPoints;
                dRemain[i] = ((p * s) / 100) / dPoints[i];
                if (dRemain[i] == 0)
                    dRemain[i] = 1;
            }
        }
    }


    function shipCombatCalcInternal(uint attack, uint aSize, uint aMode, uint defense, uint dSize, uint dMode)
        internal
        pure
        returns(uint a, uint d)
    {
        uint[2] memory aBonus;
        uint[2] memory dBonus;
        uint attackerPoints = attack * aSize;
        uint defenderPoints = defense * dSize;
        uint s;

        (aBonus[0],aBonus[1]) = getAttackBonusByMode(aMode);
        (dBonus[0],dBonus[1]) = getDefenseBonusByMode(dMode);

        /*
         * Siempre pone 1 punto de defensa como minimo.
         * En la version 1.2 Una flota con ataque 0 ataca a un ship sin puntos de defensa
         * surge el error de dividir por 0
         */
        if (defenderPoints == 0)
            defenderPoints = 1;

        if (aBonus[0] != 0 && aBonus[1] == 0) {
            attackerPoints = attackerPoints + (aBonus[0]*attackerPoints/100);
        }
        if (aBonus[0] == 0 && aBonus[1] != 0) {
            attackerPoints = attackerPoints - (aBonus[1]*attackerPoints/100);
        }
        if (dBonus[0] != 0 && dBonus[1] == 0) {
            defenderPoints = defenderPoints + (dBonus[0]*defenderPoints/100);
        }
        if (dBonus[0] == 0 && dBonus[1] != 0) {
            defenderPoints = defenderPoints - (dBonus[1]*defenderPoints/100);
        }
        
        /*
         * Gana el Atacante
         */
        if (attackerPoints > defenderPoints) 
        {
            s = 100-(100*defenderPoints/attackerPoints);
            if ( s != 0 ) {
                a = s*aSize/100;
                if (a == 0)
                    a = 1;
            } else {
                a = aSize;
            }
            d = 0;
        } else {
            s = 100-(100*attackerPoints/defenderPoints);
            if ( s != 0 ) {
                a = 0;
                d = s*dSize/100;
                if (d == 0 && dSize != 0)
                    d = 1;
            } else {
                a = 0;
                if (d == 0 && dSize != 0)
                    d = 1;
            }
        }
    }

    // Mode 0: Default    
    // Mode 1: Movemment: -10% Attack, -10% Defense, +50% Movemment
    // Mode 2: Attack:    +10% Attack, +50% distance, -10% Defense, -25%Movemment
    // Mode 3: Defense:   +30% Defense, -10% Attack, -100% Movemment
    
    function getMovemmentByMode(uint _mode)
        internal
        pure 
        returns(uint) 
    {
        uint8[4] memory movemmentPerMode = [4,6,3,0];
        return movemmentPerMode[_mode];
    }
    
       
    function getAttackBonusByMode(uint _mode)
        internal
        pure
        returns(uint,uint)
    {
        if (_mode == 0) return (0,0);
        else if (_mode == 1) return (0,10);
        else if (_mode == 2) return (25,0);
        else return (0,10);
    }
    
    function getDefenseBonusByMode(uint _mode)
        internal
        pure
        returns(uint,uint)
    {
        if (_mode == 0) return (0,0);
        else if (_mode == 1) return (0,10);
        else if (_mode == 2) return (0,10);
        else return (30,0);
    }

    function getDistanceBonusByMode(uint _mode)
        internal
        pure
        returns (uint,uint)
    {
        if (_mode == 2) return(50,0);
        else if(_mode == 3) return(0,100);
        else return(0,0);
    }

    function lockUpgradeResource(uint level, uint damage) 
        internal
        view 
        returns(uint)
    {
        uint ret;
        ret = level * 200;
        if (damage > 0) {
            ret = ((100 + damage) * ret) / 100;
        }
        return block.number + ret;
    }
    
    function lockUpgradeBuilding(uint level, uint damage)
        internal
        view 
        returns(uint)
    {
        uint ret;
        ret = level * 400;
        if (damage > 0) {
            ret = ((100 + damage) * ret) / 100;
        }
        return block.number + ret;
    }
    
    function lockMovemment(uint distance, uint mode, uint damage)
        internal
        view
        returns(uint)
    {
        uint8[4] memory movemmentPerMode = [4,6,3,0];
        uint ret;
        ret = (distance*400/movemmentPerMode[mode]);
        if (damage > 0) {
            ret = ((100 + damage) * ret) / 100;
        }
        return block.number + ret;
    }
    

    function lockFleet(uint distance, bool battle, uint damage) 
        internal 
        view 
        returns(uint)
    {
        uint ret;
        if (!battle) {
            ret = (distance * 25);
        }
        else {
            ret = (distance * 100);
        }
        if (damage > 0) {
            ret = ((100 + damage) * ret) / 100;
        }
        return block.number + ret;
    }

    function getProductionByLevel(uint level) 
        internal
        pure
        returns(uint) 
    {
        uint8[11] memory production = [0,1,2,3,4,7,10,14,20,28,40];
        return production[level];
    }

    
}
