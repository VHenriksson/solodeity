# Solodeity

Be the Solo Deity (or simply winner) of this Solidity based game by being the highest unique bidder of a number.

## Rules of the game

In solodeity, each player bets on a number between 1 and a maximal number $y$, each bet is a set price (say $x$ ETH, where $x$ is probably much smaller than 1). After $y$ people have bet their numbers, the winner is the player who has the highest _unique_ bid. If that player bid $z$, they are paid $xz$ ETH.

## Remarks

This code is not production grade and may contain bugs. The code is still in development.

Note that this contract is probably __not legal__ to publish in most jurisdisctions, due to online gambling being heavily regulated. This contract is __only for demonstration purposes__, and a way for me to learn Solidity.

## Development

This project uses [Foundry](https://getfoundry.sh). See the [docs](https://getfoundry.sh/introduction/getting-started) for instructions on how to install and use Foundry.
