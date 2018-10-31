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

    event ShipStartPlay(
        uint _id,
        uint _block
    );

    event ShipEndPlay(
        uint _id,
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
        address owner,
        uint _from
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
        address winner,
        uint reward
    );
}
