    function getResourcesLevel(uint[14] resources, uint rBuild, uint endBuild)
        internal
        view
        returns(uint[14] ret)
    {
        bool end = (endBuild < block.number);

        ret = resources;
        
        if (!end) {
            ret[rBuild] = ret[rBuild] - 1;
        }
    }
    
    function getProduction(uint[14] resources, uint[3] density, uint damage, uint eConsumption, uint rBuild, uint endBuild)
        external
        view
        returns(uint energy, uint graphene, uint metal)
    {
        uint[14] memory r;
        uint i;
        uint s;

        r = getResourcesLevel(resources,rBuild,endBuild);

        for (i = 0; i < 12; i++) {
            energy = energy + getProductionByLevel(r[i]);
        }
        graphene = getProductionByLevel(r[12]) * density[1];
        metal = getProductionByLevel(r[13]) * density[2];

        if (damage != 0) {
            s = 100 - damage;
            energy = s * energy / 100;
            graphene = s * graphene / 100;
            metal = s * metal / 100;
        }
        energy = energy - eConsumption;
    }