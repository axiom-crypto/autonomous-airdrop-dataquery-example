# Autonomous Airdrop

This example allows users to autonomously claim an airdrop of an example ERC20 token without using AxiomREPL. The example here relies only on Data Queries, which requires additional validation and a slightly different flow on the contract level. The Compute Query (AxiomREPL) version of this repository is located at: https://github.com/axiom-crypto/autonomous-airdrop-example

Users utilize a data-fetching layer on top of Axiom to autonomously prove that their account matches some parameters before submitting a Query. In this case, it is the user has used Uniswap on Goerli testnet after block 9000000. 

This example utilizes only Data Queries from the AxiomV2 SDK and does not use AxiomREPL at all.

## Contracts

`/contracts` contains all of the Solidity contract code.

## Scripts

`/scripts` contains the code that does the data fetching, Query building, and submitting to the blockchain.

## Webapp

`/webapp` does what the scripts folder does, but in a full next.js web app.
