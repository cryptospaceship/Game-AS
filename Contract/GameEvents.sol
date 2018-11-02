pragma solidity 0.4.25;

contract GameEvents {

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

    event ShipStartPlayEvent(
        uint _from,
        uint _block
    );

    event ShipEndPlayEvent(
        uint _from,
        uint _block
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
        uint _from,
        address owner
    );

    event FireCannonEvent(
        uint _from,
        uint _to,
        uint _damage,
        bool _destroyed
    );

    event FireCannonEventAccuracy(
        uint _from,
        uint _to,
        uint _target,
        uint _level,
        uint _damage_level
    );

    event SentResourcesEvent(
        uint _from,
        uint _to,
        uint _e,
        uint _g,
        uint _m
    );

    event WinnerEvent(
        uint _from,
        address winner,
        uint reward
    );
}
