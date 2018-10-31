# Game-AS
Game Arabian Shake Version

Last version Library address: 0x6C328C5B056c1F6D95D2A4Ef279109d8708bF47a

Compile Contract:

```
solc Game-AS\contract\GameShipFactory-Linked.sol --bin --abi -o Game-AS\Build --optimize --optimize-runs 1000 --overwrite
```

Link with deployed library

```
solc --link --libraries <lib-name>:<lib-address> build\GameShipFactory_linked.bin
```



C:\Users\ebilli\Documents\GitHub>solc.exe Game-AS\Contract\GamePlay.sol --bin --abi -o Game-AS\Build --overwrite --optimize --optimize-runs 1

C:\Users\ebilli\Documents\GitHub>solc --link --libraries Game-AS/Contract/GameLib.sol:GameLib:0x052ef40ccda2d51ca3d49cc3d6007b25965bec5b Game-AS\Build\GamePlay.bin
