# Game-AS
Game Arabian Shake Version


Compile Contract:

```
solc Game-AS\contract\GameShipFactory-Linked.sol --bin --abi -o Game-AS\Build --optimize --optimize-runs 1000 --overwrite
```

Link with deployed library

```
solc --link --libraries <lib-name>:<lib-address> build\GameShipFactory_linked.bin
```
