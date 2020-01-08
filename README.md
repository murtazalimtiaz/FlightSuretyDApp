# FlightSurety

FlightSurety is a sample application for flight insurance developed in Ethereum.

## Environment
```
$ truffle version
Truffle v5.0.12 (core: 5.0.12)
Solidity - ^0.4.25 (solc-js)
Node v10.15.1
Web3.js v1.0.0-beta.37
```

## Install

This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle), dApp scaffolding (using HTML, CSS and JS) and server app scaffolding.

To install, download or clone the repo, then:

`npm install`
`truffle compile`

## Develop Client

To use the dapp:

`truffle migrate`
`npm run dapp`

To view dapp:

`http://localhost:8000`

## Develop Server

`npm run server`
`truffle test ./test/oracles.js`

## Deploy

To build dapp for prod:
`npm run dapp:prod`

Deploy the contents of the ./dapp folder

# DApp UI

1. Airline registration and funding
<img src="./images/ui-fund-airline.png" alt="Drawing" style="width: 800px;"/>

2. Flights registration
<img src="./images/ui-flights.png" alt="Drawing" style="width: 800px;"/>

3. Oracles and flight status
<img src="./images/ui-oracles.png" alt="Drawing" style="width: 800px;"/>

4. Insurance Refund
<img src="./images/ui-flight-status.png" alt="Drawing" style="width: 800px;"/>

# Testing Smart Contracts

1. Testing : Airlines registration and multipartt consensus  
Run below command to test airlines registration and multiparty consensus  
`truffle test test/flightSurety.js`
<img src="./images/flightSurety.png" alt="Drawing" style="width: 800px;"/>

2. Testing : Flights registration and multipartt consensus  
Run below command to test flights registration and multiparty consensus  
`truffle test test/flights.js`
<img src="./images/flights.png" alt="Drawing" style="width: 800px;"/>

3. Testing : Oracles registrations and responses  
Run below command to test oracles registration  
`truffle test test/oracles.js`
<img src="./images/oracles.png" alt="Drawing" style="width: 800px;"/>

