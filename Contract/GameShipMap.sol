pragma solidity 0.4.24;

import "./Ownable.sol";

contract GameShipMap is Ownable {
    uint[64][64]    gameMap;
    uint            size = 4096;
    uint            sideSize = 64;
    
    modifier validPosition(uint x,uint y) {
        require(x < sideSize && y < sideSize);
        _;
    }
	
    modifier empty(uint x,uint y) {
        require(gameMap[x][y] == 0);
        _;
    }
    
   /*
    * @title Get in Position
    * @dev 
    * @param x Axis X(uint)
    * @param y Axis Y(uint)
    * @return Id of the object or 0 
    */
    function getInPosition(uint x, uint y) 
	    external 
	    view 
	    returns
        (
            uint id,
            uint grapheneDensity,
            uint metalDensity
        ) 
    {
        id = gameMap[x][y];
        (,grapheneDensity,metalDensity) = getResourceDensity(x,y);
    }
    
   /*
    * @title Get in Position
    * @dev 
    * @param x Axis X(uint)
    * @param y Axis Y(uint)
    * @return Id of the object or 0 
    */
    function getStrategicMap(uint _x, uint _y) 
	    external 
	    view 
	    returns(uint[51])
    {
        uint[51] memory ret;
        uint x;
        uint y; 
        uint i;
        uint j;

        if ( _x + 3 < sideSize && _x > 3 ) {
            x = _x - 3;
        } else {
            if ( _x + 3 >= sideSize )
                x = sideSize - 7;
            else
                x = 0;                
        }

        if ( _y + 3 < sideSize && _y > 3 ) {
            y = _y - 3;
        } else {
            if ( _y + 3 >= sideSize )
                y = sideSize - 7;
            else
                y = 0;
        }
        
        for ( i = 0; i < 7; i++ ) {
            for ( j = 0; j < 7; j++ ) { 
                ret[i*7+j] = gameMap[i+x][j+y];
            }
        }
        ret[49] = x;
        ret[50] = y;
        return ret;
    }
 
   /*
    * @title Get in Position
    * @dev 
    * @param x Axis X(uint)
    * @param y Axis Y(uint)
    * @return Id of the object or 0 
    */
    function getResourceDensity(uint x, uint y) 
    	internal 
	    view 
	    returns(uint,uint,uint) 
    {
        if (x >= sideSize || y >= sideSize)
            return (0,0,0);
        return(0,_calcDensity(x+5,y),_calcDensity(y+5,x));
    } 

   /*
    * @title Get in Position
    * @dev 
    * @param x Axis X(uint)
    * @param y Axis Y(uint)
    * @return Id of the object or 0 
    */
    function unsetInMapPosition(uint x, uint y) 
	    internal 
	    returns(uint _id) 
    {
        _id = gameMap[x][y];
        gameMap[x][y] = 0;
    } 
    
   /*
    * @title Get in Position
    * @dev 
    * @param x Axis X(uint)
    * @param y Axis Y(uint)
    * @return Id of the object or 0 
    */
    function setInMapPosition(uint _id, uint x, uint y)
	    internal 
	    validPosition(x,y) 
	    empty(x,y) 
	    returns(uint,uint)
    {
        gameMap[x][y] = _id;    
        return (x,y);
    }
	
    function changeMapSize(uint s)
        internal
    {
        size = s * s;
        sideSize = s;
    }


    function getMapPosition(uint x, uint y)
        internal
        view
        returns(uint)
    {
        return gameMap[x][y];
    }

   /*
    * @title Get in Position
    * @dev 
    * @param x Axis X(uint)
    * @param y Axis Y(uint)
    * @return Id of the object or 0 
    */
    function _calcDensity(uint x, uint y) 
	    internal 
	    view 
	    returns(uint) 
    {
        uint8[11] memory resources = [0,45,15,12,9,7,5,4,1,1,1];
        uint n = uint256(keccak256(x,y)) % size;
        uint i;
        uint top;
        uint botton;
        
        top = size;
        
        for ( i = 1; i <= 10; i++ ) {
            botton = top - (resources[i]*size/100);
            if ( n <= top && n > botton)
                return i;
            else
                top = botton;
        }
        return 0;
    }
}
