import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';

let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);

const STATUS_CODE_ON_TIME = 10;
const STATUS_CODE_LATE_FLIGHT = 20;

const ACCOUNT_OFFSET = 10; // first 10 accounts are reserved for airlines
const ORACLES_COUNT = 20;
let oracle_accounts = [];

console.log('Start server');

function initAccounts() {
  return new Promise((resolve, reject) => {
    web3.eth.getAccounts((error, accounts) => {
      console.log('Total accounts : ' + accounts.length)
      if (accounts.length < ORACLES_COUNT + ACCOUNT_OFFSET) {
        throw "Increase the number of accounts"
      }

      // Register App as authorized caller
      flightSuretyData.methods
        .authorizeCaller(config.appAddress)
        .send({ from: accounts[0] })
        .then(result => {
          console.log('App registered as authorized caller')
        });
      resolve(accounts);

    }).catch(err => {
      reject(err);
    });
  });
}

function initOracles(accounts) {
  return new Promise((resolve, reject) => {
    console.log('>> Initialized Oracles');
    flightSuretyApp.methods.REGISTRATION_FEE().call().then(fee => {
      console.log('Registration fee is : ' + web3.utils.fromWei(fee, 'ether') + ' ether')

      // Register Oracles
      for (let oidx = ACCOUNT_OFFSET; oidx < ORACLES_COUNT + ACCOUNT_OFFSET; oidx++) {
        flightSuretyApp.methods
          .registerOracle()
          .send({ from: accounts[oidx], value: fee, gas: 3000000 }, (reg_error, reg_result) => {
            if (reg_error) {
              console.log(reg_error);

            } else {

              // Fetch Indexes for a specific oracle account
              flightSuretyApp.methods
                .getMyIndexes()
                .call({ from: accounts[oidx] }, (error, indexes) => {
                  if (error) {
                    console.log(error);
                  } else {
                    // Added registered account to oracle account list
                    let oracle = {
                      address: accounts[oidx],
                      indexes: indexes
                    };

                    oracle_accounts.push(oracle);
                    console.log("Oracle registered: " + JSON.stringify(oracle));
                  }
                });
            }
          });
      }

      resolve(oracle_accounts);
    })
      .catch(err => {
        //console.log(err)
        reject(err)
      });
  });
}

function simulateOracelResponse(oracles) {
  return new Promise((resolve, reject) => {
    console.log('>> Simulate Oracel Response');
    flightSuretyApp.events.OracleRequest({
      fromBlock: 0
    }, function (error, event) {
      if (error) console.log(error)
      else {
        console.log('Event emmited from smart contract : ' + JSON.stringify(event.event));
        let payload = {
          index: event.returnValues.index,
          airline: event.returnValues.airline,
          flight: event.returnValues.flight,
          timestamp: event.returnValues.timestamp,
          statusCode: STATUS_CODE_ON_TIME
        }
        console.log("Payload : " + JSON.stringify(payload));
        // Select status code based on flight time


        if ((payload.timestamp * 1000) < Date.now()) {
          payload.statusCode = STATUS_CODE_LATE_FLIGHT;
        }

        // Fetching Indexes for Oracle Accounts
        for (let oidx = 0; oidx < oracle_accounts.length; oidx++) {

          if (oracle_accounts[oidx].indexes.includes(payload.index)) {
            console.log("Oracle matches with requested index : " + JSON.stringify(oracle_accounts[oidx]));

            // Submit Oracle Response
            flightSuretyApp.methods
              .submitOracleResponse(payload.index, payload.airline, payload.flight, payload.timestamp, payload.statusCode)
              .send({ from: oracle_accounts[oidx].address, gas: 200000 }, (error, result) => {
                if (error) {
                  console.log('Tx error : ' + error.message);
                } else {
                  console.log("Sended Oracle Response " + JSON.stringify(oracle_accounts[oidx]) + " Status Code: " + payload.statusCode);
                }
              });
          }
        }
      }
    });

  });
}


initAccounts()
  .then(accounts => {
    initOracles(accounts)
  }).then(oracles => {
    simulateOracelResponse(oracles)
  }).then(() => {
    initREST();
  });;

// Initialize rest endpoints
const app = express();
function initREST() {
  console.log('>> Initialized rest API');
  app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
  })
}

export default app;
