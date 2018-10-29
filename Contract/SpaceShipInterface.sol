pragma solidity ^0.4.25;

contract SpaceShipInterface {

    function getQAIM(uint _ship, uint qaim) external view returns(uint);

    function getShip(uint _ship)    
        external 
        view 
        returns 
        (
            address owner,
            string name,
            uint color,
            uint gen,
            uint points,
            uint level,
            uint plays,
            uint wins,
            uint launch,
            uint progress,
            uint qaims,
            bool inGame
        );

    function getShipQaim(uint _ship) external view returns(uint8[32] qaim);
        
    function setGame(uint _ship) external;

}


