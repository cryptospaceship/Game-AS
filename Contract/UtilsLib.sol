pragma solidity 0.4.24;

library Utils {

    function getDistance(uint[2] a, uint[2] b)
        internal
        pure 
        returns(uint)
    {
        uint d = 0;
        
        if (a[0] < b[0])
            d = b[0] - a[0]; 
        else 
            d = a[0] - b[0];

        if (a[1] < b[1])
            d += b[1] - a[1]; 
        else 
            d += a[1] - b[1];
            
        return d;
    }

}