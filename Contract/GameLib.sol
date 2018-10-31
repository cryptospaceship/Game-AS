pragma solidity 0.4.25;

//import "./fisics/rsk.sol";
import "./fisics/kovan.sol";
//import "./fisics/rskTestnet.sol";
//import "./fisics/ethereum.sol";
//import "./fisics/poa.sol";


library GameLib {
/*  enum ResourceIndex {
        INDEX_UPGRADING,
        PANEL_1,
        PANEL_2,
        PANEL_3,
        PANEL_4,
        PANEL_5,
        PANEL_6,
        GRAPHENE,
        METAL
    }

    enum BuildingIndex {
        INDEX_UPGRADING,
        WAREHOUSE,
        HANGAR,
        WOPR
    }
    
    enum QAIM {
        FLEET_POINTS,
        RESOURCES_IMPROVE,
        BUILDINGS_IMPROVE,
        FLEET_IMPROVE,
        SHIP_MOVEMMENT_IMPROVE,
        MODE_IMPROVE
    } */



    function getConvertionRate(uint resource, uint converterLevel, uint damage)
        external
        view
        returns(uint resConverted, uint lock)
    {
        if (converterLevel == 2)
            resConverted = resource / 2;
        else
            resConverted = resource / 4;

        lock = lockConverter(converterLevel,damage);
    }


    function getProductionToConverter(uint[9] level, uint endUpgrade, uint converterLevel)
        external
        view
        returns(uint graphene, uint metal)
    {
        if (level[0] == 7 && endUpgrade > block.number)
            graphene = getProductionByLevel(level[7]-1);
        else
            graphene = getProductionByLevel(level[7]);

        if (level[0] == 8 && endUpgrade > block.number)
            metal = getProductionByLevel(level[8]-1);
        else
            metal = getProductionByLevel(level[8]); 

        if (converterLevel == 1) {
            graphene = graphene / 2;
            metal = metal / 2;
        }
    }

    /**
     */

    function changeMode(uint damage, uint qaim)
        external
        view
        returns(uint, uint)
    {
        return(lockChangeMode(damage,qaim),bFisics.val(2000));
    }


    /**
     * @dev checkRange(): Comprueba si la nave principal se puede mover determinada
     * distancia
     * @param distance Distancia de movimiento
     * @param mode Modo de la nave principal. -> 0, 1, 2, 3
     * @param damage Daño de la nave de 0 a 100
     * @return inRange Booleano para saber si la nave se puede mover
     * @return lock Cantidad de bloques para el proximo movimiento
     */
    function checkRange(uint distance, uint mode, uint damage, uint qaim)
        external
        view
        returns(bool inRange, uint lock)
    {
        inRange = (distance <= getMovemmentByMode(mode) && distance != 0);
        if (inRange) 
            lock = lockMovemment(distance,mode,damage,qaim);
        else
            lock = 0;
    }

    function checkRepair(uint distance, uint level, uint damageToRepair, uint damage)
        external
        view
        returns(bool valid, uint energy, uint graphene, uint metal, uint lock)
    {
        valid = (distance == 0) || (distance == 1 && ( (level == 1 && damageToRepair <=10) || (level == 2 && damageToRepair <= 20)));
        if (valid) {
            (energy,graphene,metal) = getRepairCost(damageToRepair);
            lock = lockRepair(level,damage);
        }
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
    function checkCannonRange(uint distance, uint level, uint shipDamage, bool accuracy, bool isOtherReparer)
        external
        view
        returns(bool inRange, uint damage, uint cost, uint lock)
    {
        if (accuracy) {
            inRange = (distance <= 2 && level == 2);
            if (inRange) {
                damage = getCannonDamage(level,distance,true,isOtherReparer);
                cost = getFireCannonCost(true);
                lock = bFisics.val(400); // Esto no me gusta
                if (shipDamage > 0) {
                    lock = ((100 + shipDamage) * lock) / 100;
                }
                lock = block.number + lock;
            }
        } else { 
            inRange = (level > 0 && (distance == 1 || (distance == 2 && level == 2)));
            if (inRange) {
                damage = getCannonDamage(level,distance,false,isOtherReparer);
                cost = getFireCannonCost(false);
                lock = bFisics.val(300); // Esto no me gusta
                if (shipDamage > 0) {
                    lock = ((100 + shipDamage) * lock) / 100;
                }
                lock = block.number + lock;
            }
        }
    }


    /**
     * @dev getProduction(): Calcula la produccion total de la nave
     * @param rLevel Array de 9 posiciones, con el nivel de cada panel 6 primera posiciones y las 
     * otras dos para el colector de grafeno y para el colector de metales
     * @param density Array de dos posisciones con la densidad de Graphene y Metal
     * @param eConsumption consumo de la nave
     * @param damage Daño de la nave principal (Afecta la produccion)
     * @param gConverter Graphene converter
     * @param mConverter Metal converter
     * @return energy: Produccion total de energia
     * @return graphene: Produccion total de graphene
     * @return metal: Produccion total de metales
     */
    function getProduction(uint[9] rLevel, uint endUpgrade, uint[3] density, uint eConsumption, uint damage, uint gConverter, uint mConverter)
        external
        view
        returns(uint energy, uint graphene, uint metal)
    {
        if (endUpgrade > block.number)
            (energy,graphene,metal) = getProductionInternal(subResourceLevel(rLevel),density,eConsumption,damage,gConverter,mConverter);
        else
            (energy,graphene,metal) = getProductionInternal(rLevel,density,eConsumption,damage,gConverter,mConverter);        
    }

    /**
     * @dev getUnharvestResources(): Trae los recursos no cosechados
     * @param rLevel Array de 9 posiciones.
     *               0: Recurso que se esta ampliando
     *               1: Panel energia 1
     *               2: Panel energia 2
     *               3: Panel energia 3
     *               4: Panel energia 4
     *               5: Panel energia 5
     *               6: Panel energia 6
     *               7: Colector de Grapheno
     *               8: Colector de Metales
     * @param endUpgrade Numero de bloque en que la actualizacion de recursos va a finalizar
     * @param density Array de 3 posiciones con la densidad de recursos
     * @param eConsumption Consumo de enegia
     * @param damage Daño de la nave
     * @param lastHarvest Ultima vez que se "cosecho"
     * @param gConverter Graphene converter
     * @param mConverter Metal converter
     */
    function getUnharvestResources(uint[9] rLevel, uint endUpgrade, uint[3] density, uint eConsumption, uint damage, uint lastHarvest, uint gConverter, uint mConverter)
        external
        view
        //returns(uint energy, uint graphene, uint metal)
        returns(uint[3] resources)
    {
        uint b = block.number;
        uint diff;
        uint e;
        uint g;
        uint m;

        //energy = 0;
        //graphene = 0;
        //metal = 0;
        resources[0] = 0;
        resources[1] = 0;
        resources[2] = 0;

        if (endUpgrade > b) {
            /*
             * En este punto todavia no se termino de hacer el upgrade
             * entonces quiere decir que hay un nivel que no hay que contemplarlo
             * que es el que se esta ampliando
             */
            (e,g,m) = getProductionInternal(subResourceLevel(rLevel),density,eConsumption,damage,gConverter,mConverter);
            diff = b - lastHarvest;

        } else {
            /*
             * Ya se termino de hacer el upgrade, y ahora hay que preguntarse cuando 
             * se termino de realizar el upgrade, antes del last harvest o despues
             */
            if (endUpgrade > lastHarvest) {
                /*
                 * El upgrade termino luego de la ultima "cosecha", entonces hay que calcular
                 * la produccion de dos maneras:
                 * 1- Desde la ultima "cosecha" hasta que termino el upgrade
                 * 2- Desde que termino el upgrade hasta el bloque actual
                 */

                // 1
                diff = endUpgrade - lastHarvest;
                (e,g,m) = getProductionInternal(subResourceLevel(rLevel),density,eConsumption,damage,gConverter,mConverter);
                resources[0] = e * diff;
                resources[1] = g * diff;
                resources[2] = m * diff;

                // 2
                diff = b - endUpgrade;
                (e,g,m) = getProductionInternal(rLevel,density,eConsumption,damage,gConverter,mConverter);
            }
            else {
                /*
                 * La ultima cosecha fue posterior a la cuando finalizo la construccion
                 */
                diff = b - lastHarvest;
                (e,g,m) = getProductionInternal(rLevel,density,eConsumption,damage,gConverter,mConverter);
            }
        }

        /*
         * Suma todos los recursos
         */
        resources[0] = resources[0] + (e * diff);
        resources[1] = resources[1] + (g * diff);
        resources[2] = resources[2] + (m * diff);
    }

    /**
     * @dev getProductionInternal(): Calcula la produccion total de la nave
     * @param rLevel Array de 8 posiciones, con el nivel de cada panel 6 primera posiciones y las 
     * otras dos para el colector de grafeno y para el colector de metales
     * @param density Array de dos posisciones con la densidad de Graphene y Metal
     * @param eConsumption consumo de la nave
     * @param damage Daño de la nave principal (Afecta la produccion)
     * @param gConverter Graphene converter
     * @param mConverter Metal converter
     * @return energy: Produccion total de energia
     * @return graphene: Produccion total de graphene
     * @return metal: Produccion total de metales
     */
    function getProductionInternal(uint[9] rLevel, uint[3] density, uint eConsumption, uint damage, uint gConverter, uint mConverter)
        internal
        pure
        returns(uint energy, uint graphene, uint metal)
    {
        uint s;
        graphene = (getProductionByLevel(rLevel[7]) - gConverter) * density[1];
        metal = (getProductionByLevel(rLevel[8]) - mConverter) * density[2];

        if (damage != 0) {
            s = 100 - damage;
            graphene = s * graphene / 100;
            metal = s * metal / 100;
        }
        energy = getEnergyProduction(rLevel, eConsumption,damage,gConverter+mConverter);
    }

    function subResourceLevel(uint[9] level)
        internal
        pure
        returns(uint[9] ret)
    {
        ret = level;
        if (ret[0] != 0 )
            ret[ret[0]]--;
    }


    function getEnergyProduction(uint[9] panels, uint eConsumption, uint damage, uint aEnergy)
        internal
        pure
        returns(uint energy)
    {
        uint i;
        energy = 0;
        for (i = 1; i <= 6; i++) {
            energy = energy + (getProductionByLevel(panels[i]) * 2);
        }
        energy = energy + aEnergy;
        if (damage != 0) {
            energy = (100 - damage) * energy / 100;
        }
        energy = energy - eConsumption;
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

        (aRemain, dRemain) = portCombatCalcInternal(attacker[0],attacker[1],dPoints,dSize);
    }

    function shipCombatCalc(uint[5] attacker, uint[3] defender, uint distance, bool battle)
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
        if (battle)
            (aRemain,dRemain) = shipCombatCalcBattle(attacker[0],attacker[1],attacker[3],defender[0],defender[1],defender[2]);
        else
            (aRemain,dRemain) = shipCombatCalcSkirmish(attacker[0],attacker[1],attacker[3],defender[0],defender[1],defender[2]);
    }
    
    function getFleetEndProduction(uint size, uint hangarLevel, uint[9] rLevel, uint resourceEndUpgrade, uint eConsumption, uint damage, uint gConverter, uint mConverter, uint qaim)
        external
        view
        returns(bool,uint)
    {
        uint _block = block.number;
        uint batches = (size/48) + 1;
        uint ret;
        ret = batches * (5-hangarLevel) * bFisics.val(80);
        if (damage > 0) {
            ret = ((100 + damage) * ret) / 100;
        }
        if (qaim > 0) {
            ret = ret - _percent(ret,qaim);
        }
        if (resourceEndUpgrade > _block)
            return ((size <= getEnergyProduction(subResourceLevel(rLevel), eConsumption, damage, gConverter+mConverter)),(_block + ret));
        return ((size <= getEnergyProduction(rLevel, eConsumption, damage, gConverter+mConverter)),(_block + ret));
    }


    function validFleetDesign(uint _attack, uint _defense, uint _distance, uint _load, uint hangarLevel, uint qaim)
        external
        pure
        returns(bool)
    {
        uint p = _attack + _defense + (_distance * 6) + (_load/80);
        uint points = qaim + getPointsByHangarLevel(hangarLevel);
        return ( p <= points && p != 0);
    }


    function calcReturnResourcesFromFleet(uint _hangarLevel, uint _attack, uint _defense, uint _distance, uint _load, uint _size)
        external
        pure
        returns(
            uint e,
            uint g,
            uint m
        )
    {
        uint p = getResourcesToReturn(_hangarLevel);
        (e,g,m) = getFleetValue(_attack,_defense,_distance,_load,_size);
        e = 0;
        g = p * g / 100;
        m = p * m / 100;
    }



    function getFleetCost(uint _attack, uint _defense, uint _distance, uint _load, uint qaim)
        external
        pure
        returns(
            uint fleetType,
            uint e, 
            uint g, 
            uint m
        ) 
    {

        (e,g,m) = getFleetCostBasic(_attack,_defense,_distance,_load);
        fleetType = getFleetType(_attack,_defense,_distance,_load);
        e = e - _percent(e,qaim);
        g = g - _percent(g,qaim);
        m = m - _percent(m,qaim);
    }

    function getResourcesToReturn(uint hangarLevel) 
        internal
        pure
        returns(uint)
    {
        if (hangarLevel == 0)
            return 0;
        return (hangarLevel-1) * 10;
    }

    function getFleetCostBasic(uint _attack, uint _defense, uint _distance, uint _load)
        internal
        pure
        returns(
            uint e,
            uint g,
            uint m
        )
    {
        e = bFisics.val(20) * (_attack + _defense + (_distance*6) + (_load/bFisics.val(80)));
        g = bFisics.val(70) * (_defense + (_distance*6)) + (bFisics.val(50)*_attack) + (bFisics.val(30)*(_load/bFisics.val(80)));
        m = bFisics.val(70) * (_attack + (_load/bFisics.val(80))) + (bFisics.val(50)*_defense) + (bFisics.val(30)*(_distance*6));
    }

    function getFleetValue(uint _attack, uint _defense, uint _distance, uint _load, uint _size)
        internal
        pure
        returns(
            uint e,
            uint g,
            uint m
        )
    {
        (e,g,m) = getFleetCostBasic(_attack,_defense,_distance,_load);
        e = e * _size;
        g = g * _size;
        m = m * _size;
    }


    function getWarehouseLoadByLevel(uint level)
        external
        pure
        returns(uint)
    {
        uint24[5] memory warehouseStorage = [10000, 50000, 150000, 1300000, 16000000];
        return bFisics.val(warehouseStorage[level]);
    }
    
    function getUpgradeBuildingCost(uint _type, uint _level, uint damage, uint qaim) 
        external 
        view 
        returns(uint energy, uint graphene, uint metal, uint lock)
    {
        uint24[5] memory buildingCost = [0,5292,26168,120965,559164];
        /*
            Nuevos Costos Propuestos
            6933   Level 1
            32051  Level 2
            148156 Level 3
            684855 Level 4 
        */

        /*
            WOPR: _type == 2 ahora es el WOPR y habria que multiplicar por 4 y utilizar 3 y 4
         */
        if (_type == 2) { 
            energy = bFisics.val(buildingCost[_level+2]*4);
            graphene = bFisics.val(buildingCost[_level+2]*4);
            metal = bFisics.val(buildingCost[_level+2]*4);
        } else {
            energy = bFisics.val(buildingCost[_level]);
            graphene = bFisics.val(buildingCost[_level]);
            metal = bFisics.val(buildingCost[_level]);
        }
        energy = energy - _percent(energy,qaim);
        graphene = graphene - _percent(graphene,qaim);
        metal = metal - _percent(metal,qaim);

        lock = lockUpgradeBuilding(_level,damage,qaim);
    }
    
    function getUpgradeResourceCost(uint _type, uint _level, uint damage, uint qaim) 
        external
        view
        returns(uint energy, uint graphene, uint metal, uint lock)
    {
        uint24[11] memory resourceCost = [0,1200,2520,5292,12171,26168,56263,120965,260076,559164,1202204];
        /*
            2584738 Level 11
            5557187 Level 12
            ----------------
            Nuevos Costos Propuestos
            1500    Level 1
            3225    Level 2
            6933    Level 3 
            14907   Level 4
            32051   Level 5
            68910   Level 6
            148156  Level 7    
            318537  Level 8
            684855  Level 9
            1472439 Level 10
            3165744 Level 11 <- Nuevos Niveles - Solo Energia 
            6806350 Level 12 <- Nuevos Niveles - Solo Energia
        */
        if (_type == 0) {
            energy = bFisics.val(resourceCost[_level]);
            graphene = bFisics.val(resourceCost[_level]*2);
            metal = bFisics.val(resourceCost[_level]*2);
        } else if (_type == 1) {
            energy = bFisics.val(resourceCost[_level]);
            graphene = bFisics.val(resourceCost[_level]/2);
            metal = bFisics.val(resourceCost[_level]);
        } else if (_type == 2) {
            energy = bFisics.val(resourceCost[_level]);
            graphene = bFisics.val(resourceCost[_level]);
            metal = bFisics.val(resourceCost[_level]/2);
        }

        energy = energy - _percent(energy,qaim);
        graphene = graphene - _percent(graphene,qaim);
        metal = metal - _percent(metal,qaim);

        lock = lockUpgradeResource(_level, damage, qaim);
    
    }

    function getBlocksToWin()
        external
        pure
        returns(uint)
    {
        return bFisics.val(20000);
    }

    function getInitialWarehouse()
        external
        pure 
        returns(uint, uint, uint)
    {
        uint s = bFisics.val(10000);
        return(s,s,s);
    }
    
    function checkFleetRange(uint distance, uint fleetRange, uint mode, uint damage, bool _battle)
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
            lock = lockFleet(distance,_battle,damage);
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
        uint _d = _distance * 6;
        uint _l = _load/bFisics.val(80);
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

    function getCannonDamage(uint cannonLevel, uint distance, bool accuracy, bool isOtherReparer)
        internal
        pure
        returns (uint ret)
    {
        uint rdiv;

        if (isOtherReparer)
            rdiv = 2;
        else
            rdiv = 1;

        if (accuracy) {
            if (distance == 2)
                ret = 50;
            else
                ret = 100;
        }
        else {
            ret = (cannonLevel * 10)/distance;
        }
        ret = ret / rdiv;
    }

    function getPointsByHangarLevel(uint hangarLevel)
        internal
        pure
        returns(uint)
    {
        uint8[5] memory p = [0,60,70,85,100];
        return p[hangarLevel];
    }
    
    function getFireCannonCost(bool accuracy)
        internal
        pure
        returns (uint)
    {
        if (accuracy)
            return bFisics.val(3000000);
        return bFisics.val(2000000);
    }

    function getRepairCost(uint units)
        internal
        pure
        returns(uint energy, uint graphene, uint metal)
    {
        energy = bFisics.val(100000) * units;
        graphene = bFisics.val(200000) * units;
        metal = bFisics.val(200000) * units;
    }

    function portCombatCalcInternal(uint aPoints, uint aSize, uint[5] dPoints, uint[5] dSize)
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
            s = 100-(_divRound(100*defenderPoints,attackerPoints));
            if ( s != 0 ) {
                aRemain = _divRound(s*aSize,100);
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
                if (dSize[i] == 0 || dPoints[i] == 0) {
                    dRemain[i] = 0;
                } else {
                    p = _divRound(dPoints[i] * dSize[i] * 100, defenderPoints);
                    dRemain[i] = _divRound(p * s, 100);
                    dRemain[i] = _divRound(dRemain[i],dPoints[i]);
                    if (dRemain[i] == 0)
                        dRemain[i] = 1;
                }
            }
        }
    }

    function _divRound(uint a, uint b) 
        internal
        pure
        returns(uint)
    {
        uint d = ((a * 100) / b);
        uint r = d % 100;
        d = d / 100;

        if (r >= 50) 
            return d + 1;
        return d;
    }

    function _percent(uint n, uint p)
        internal
        pure
        returns(uint)
    {
        return p*n/100;
    }


    function shipCombatCalcBattle(uint attack, uint aSize, uint aMode, uint defense, uint dSize, uint dMode)
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
            s = 100-battle(attackerPoints,defenderPoints);
            //s = 100-(100*defenderPoints/attackerPoints);
            if ( s != 0 ) {
                a = s*aSize/100;
                if (a == 0)
                    a = 1;
            } else {
                a = aSize;
            }
            d = 0;
        } else {
            s = 100-battle(defenderPoints,attackerPoints);
            //s = 100-(100*attackerPoints/defenderPoints);
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


    function shipCombatCalcSkirmish(uint attack, uint aSize, uint aMode, uint defense, uint dSize, uint dMode)
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

        if (attackerPoints > defenderPoints)
        {
            s = sack(attackerPoints,defenderPoints);
            a = (100-s)*aSize/100;
            d = s*dSize/100;
        } else {
            s = sack(defenderPoints,attackerPoints);
            a = s*aSize/100;
            d = (100-s)*dSize/100;
        } 
    }

    function battle(uint w, uint l)
        internal
        pure
        returns (uint)
    {
        uint c = _divRound(100*l,w);
        if ( c <= 25 )
            return c - _divRound(c,2);
        if ( c <= 50 )
            return c - _divRound(c,3);
        if ( c <= 75 )
            return c - _divRound(c,4);
        if ( c < 90 )
            return c - _divRound(c,8);
        return c;   
    }

    function sack(uint w, uint l)
        internal
        pure
        returns(uint)
    {
        uint c = battle(w,l);
        return _divRound(100*c,100+c);
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
        else if(_mode == 3) return(0,50);
        else return(0,0);
    }

    function lockUpgradeResource(uint level, uint damage, uint qaim) 
        internal
        view 
        returns(uint)
    {
        uint ret;
        ret = level * bFisics.val(160);
        if (damage > 0) {
            ret = ((100 + damage) * ret) / 100;
        }
        if (qaim > 0) {
            ret = ret - _percent(ret,qaim);
        }
        return block.number + ret;
    }
    
    function lockUpgradeBuilding(uint level, uint damage, uint qaim)
        internal
        view 
        returns(uint)
    {
        uint ret;
        ret = level * bFisics.val(400);
        if (damage > 0) {
            ret = ((100 + damage) * ret) / 100;
        }
        if (qaim > 0) {
            ret = ret - _percent(ret,qaim);
        }
        return block.number + ret;
    }
    
    function lockChangeMode(uint damage, uint qaim) 
        internal
        view 
        returns(uint)
    {
        uint ret;
        ret = bFisics.val(280);
        if (damage > 0) {
            ret = ((100 + damage) * ret) / 100;
        }
        if (qaim > 0) {
            ret = ret - _percent(ret,2*qaim);
        }
        return block.number + ret;
    }

    function lockRepair(uint level, uint damage)
        internal
        view
        returns(uint)
    {
        uint ret;
        if (level == 1)
            ret = bFisics.val(600);
        else
            ret = bFisics.val(450);

        if (damage > 0) {
            ret = ((100 + damage) * ret) / 100;
        }
        return block.number + ret;
    }

    function lockConverter(uint level, uint damage)
        internal
        view
        returns(uint)
    {
        uint ret;
        if (level == 1)
            ret = bFisics.val(700);
        else
            ret = bFisics.val(500);

        if (damage > 0) {
            ret = ((100 + damage) * ret) / 100;
        }
        return block.number + ret;
    }

    function lockMovemment(uint distance, uint mode, uint damage, uint qaim)
        internal
        view
        returns(uint)
    {
        uint8[4] memory movemmentPerMode = [4,6,3,0];
        uint ret;
        ret = (distance*bFisics.val(400)/movemmentPerMode[mode]);
        if (damage > 0) {
            ret = ((100 + damage) * ret) / 100;
        }
        if (qaim > 0) {
            ret = ret - _percent(ret,2*qaim);
        }
        return block.number + ret;
    }
    

    function lockFleet(uint distance, bool _battle, uint damage) 
        internal 
        view 
        returns(uint)
    {
        uint ret;
        if (!_battle) {
            ret = (distance * bFisics.val(25));
        }
        else {
            ret = (distance * bFisics.val(100));
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
        uint8[11] memory production = [0,1,2,3,4,7,10,14,20,28,40]; // ...56,80 = 80*12 = 
        /*
            56 Level 11
            80 Level 12
        */
        return production[level];
    }   
}
