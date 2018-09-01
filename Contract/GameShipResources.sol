pragma solidity ^0.4.23;

contract GameShipResources {

    struct Resources {
        uint[12]  energyPanelLevel;
        uint      grapheneCollectorLevel;
        uint      metalCollectorLevel;
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
}