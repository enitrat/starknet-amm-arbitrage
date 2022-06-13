# An AMM arbitrage bot on Starknet

As more and more AMM are building on Starknet, it is becoming more and more important to be able to arbitrage between these protocols.
This repo is a proof of concept of how to do this.

Note : This repo is purely a PoC and is not intended to be used elsewhere. The calculations are totally unsafe, not compatible with ERC20 and not tested on any live AMM. It is only provided for learning purposes and needs to be improved a lot to be efficient.
Besides that, it's still WIP.
## Maths

The most important part of this bot is the underlying math.

WIP

## Code

I used the awesome [`Protostar`](https://docs.swmansion.com/protostar/) toolchain to develop this project.
It allows me to test every function of my code, to make sure that is working as intended,
and to make sure that I don't have any unwanted bugs.

The `tests` folder contains all the tests that I have written, to verify the correctness of the underlying math and how it plugs-in 
to an AMM protocol.

The `src` folder contains the contracts used.

