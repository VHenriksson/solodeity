# Solodeity

Be the Solo Deity (or simply winner) of this Solidity based game by being the highest unique bidder of a number.

## Rules of the game

In solodiety, each player bets on a number between 1 and 10000, each bet is a set price (say $x$ ETH, where $x$ is probably much smaller than 1). After 10000 people have bet their numbers, the winner is the player who has the highest unique bid. If that player bid $y$, they are paid $xy$ ETH.

## Remarks

This code is not production grade and may contain bugs.

Note that this contract is probably __not legal__ to publish in most jurisdisctions, due to online gambling being heavily regulated. This contract is __only for demonstration purposes__, and a way for me to learn Solidity.

## Development

This project uses [Foundry](https://getfoundry.sh). See the [book](https://book.getfoundry.sh/getting-started/installation.html) for instructions on how to install and use Foundry.
