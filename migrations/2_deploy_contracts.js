const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');

module.exports = function(deployer, network, accounts) {

    let firstAirline = accounts[1];
    deployer.deploy(FlightSuretyData)
    .then(() => {
        return deployer.deploy(FlightSuretyApp, FlightSuretyData.address, firstAirline)
                .then(async() => {
                    let config = {
                        localhost: {
                            url: 'http://localhost:8545',
                            dataAddress: FlightSuretyData.address,
                            appAddress: FlightSuretyApp.address
                        }
                    }

                    fs.writeFileSync(__dirname + '/../src/dapp/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
                    fs.writeFileSync(__dirname + '/../src/server/config.json',JSON.stringify(config, null, '\t'), 'utf-8');

                    // let flightSuretyData = await FlightSuretyData.new();
                    // let flightSuretyApp = await FlightSuretyApp.new(flightSuretyData.address, firstAirline);
                    // await flightSuretyData.authorizeCaller(flightSuretyApp.address);

                });
    });
}