
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  const SEED_FUND = web3.utils.toWei("10", "ether")
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

    // Ensure that access is denied for non-Contract Owner account
    let accessDenied = false;
    try {
      await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
    }
    catch (e) {
      accessDenied = true;
    }
    assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

    // Ensure that access is allowed for Contract Owner account
    let accessDenied = false;
    try {
      await config.flightSuretyData.setOperatingStatus(false);
    }
    catch (e) {
      accessDenied = true;
    }
    assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

    // Status is already false
    //await config.flightSuretyData.setOperatingStatus(false);

    let reverted = false;
    try {
      // This will throw exception due to operational status
      await config.flightSuretyData.registerAirline(config.testAddresses[3]);
    }
    catch (e) {
      reverted = true;
    }
    assert.equal(reverted, true, "Access not blocked for requireIsOperational");

    // Set it back for other tests to work
    await config.flightSuretyData.setOperatingStatus(true);

  });


  it('(airline) cannot deposit less than seed funds', async () => {
    // ARRANGE
    const LESS_FUND = web3.utils.toWei("9", "ether")

    let reverted = false;
    // ACT
    try {
      await config.flightSuretyApp.fundAirline({ from: config.firstAirline, value: LESS_FUND, gasPrice: 0 })
    }
    catch (e) {
      reverted = true
    }
    // ASSERT
    assert.equal(reverted, true, "Airline should not be able to deposit less than seed funds");

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    let reverted = false;
    try {
      await config.flightSuretyApp.registerAirline(newAirline, { from: config.firstAirline });
    }
    catch (e) {
      console.log(e.message)
      reverted = true;
    }
    let result = await config.flightSuretyData.isAirline.call(newAirline);

    // ASSERT
    assert.equal(reverted, true, "Revert:Airline should not be able to register another airline if it hasn't provided funding");
    assert.equal(result, false, "Result:Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('(airline) can deposit funds', async () => {
    // ARRANGE
    let reverted = false;

    // ACT
    try {
      await config.flightSuretyApp.fundAirline({ from: config.firstAirline, value: SEED_FUND, gasPrice: 0 })
    }
    catch (e) {
      console.log(e)
      reverted = true
    }
    let isFunded = await config.flightSuretyData.isAirlineFunded.call(config.firstAirline);

    // ASSERT
    assert.equal(isFunded, true, "Airline should be able to deposit funds");

  });


  it('(airline) only registered(funded) airlines can register an Airline using registerAirline()', async () => {
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
      // First airline is funded
      await config.flightSuretyApp.fundAirline({ from: config.firstAirline, value: SEED_FUND, gasPrice: 0 })
      await config.flightSuretyApp.registerAirline(newAirline, { from: config.firstAirline });
    }
    catch (e) {
      //console.log(e)
    }
    let result = await config.flightSuretyData.isAirline.call(newAirline);

    // ASSERT
    assert.equal(result, true, "Existing Airline should be able to register another airline");

  });

  it('(airline) cannot register an Airline twice', async () => {
    // ARRANGE
    let newAirline = accounts[2];

    let result;
    let reverted = false;
    // ACT
    try {
      result = await config.flightSuretyApp.registerAirline(newAirline, { from: config.firstAirline });
      // Try to register airline again
      await config.flightSuretyApp.registerAirline(newAirline, { from: config.firstAirline });
    }
    catch (e) {
      reverted = true;
    }

    // ASSERT
    //assert.equal(result[0], true, "First airline should be registered");
    assert.equal(reverted, true, "Airline should not be able to register another airline twice");

  });


  it('(multiparty-consensus) Airline is not registered due to Insufficient votes', async () => {
    // ARRANGE
    // Register 3rd airline
    await config.flightSuretyApp.registerAirline(accounts[3], { from: config.firstAirline });

    // To register 4rth airline 1/2 consensus required
    let newAirline = accounts[4]

    let success = false;
    let reverted = false;
    // ACT
    try {
      // Cast vote = 1 (Require total 2/3 votes)
      await config.flightSuretyApp.registerAirline(newAirline, { from: config.firstAirline });
    }
    catch (e) {
      console.log(e.message)
    }
    let votes = await config.flightSuretyApp.getVotes.call(newAirline);
    // console.log('Votes for : ' + newAirline)
    // console.log(JSON.stringify(votes))
    let isAirline = await config.flightSuretyData.isAirline.call(newAirline);
    // ASSERT
    assert.equal(votes.length, 1, "Must have 1 vote casted")
    assert.equal(isAirline, false, "Airline not registered, requires 1/2 consensus for registration");

  });


  it('(multiparty-consensus) Airline cannot cast vote without funding', async () => {
    // ARRANGE
    let notFundedAccount = accounts[2]

    // To register 4rth airline 1/2 consensus required
    let newAirline = accounts[4]

    let reverted = false;
    // ACT
    try {
      // Cast vote = 1 (Require total 2/3 votes)
      await config.flightSuretyApp.registerAirline(newAirline, { from: notFundedAccount });
    }
    catch (e) {
      console.log(e.message);
      reverted = true
    }

    // ASSERT
    assert.equal(reverted, true, "Airline cannot cast vote without funding");

  });


  it('(multiparty-consensus) Airline cannot cast vote twice', async () => {
    // ARRANGE
    let newAirline = accounts[4]

    let reverted = false;
    // ACT
    try {
      // Try to cast vote again
      let res = await config.flightSuretyApp.registerAirline(newAirline, { from: config.firstAirline });
    }
    catch (e) {
      console.log(e.message)
      reverted = true
    }

    // ASSERT
    assert.equal(reverted, true, "Airline cannot cast vote twice");

  });


  it('(multiparty-consensus) Airline is registered with 1/2 votes', async () => {
    // ARRANGE
    // Fund 2nd airline
    let fundedAccount = accounts[3]
    await config.flightSuretyApp.fundAirline({ from: fundedAccount, value: SEED_FUND, gasPrice: 0 })
    let newAirline = accounts[4]
    let reverted = false;

    // ACT
    try {
      // Cast 2nd vote (2/3)
      await config.flightSuretyApp.registerAirline(newAirline, { from: fundedAccount });
    }
    catch (e) {
      console.log(e.votes)
      reverted = true
    }
    let isAirline = await config.flightSuretyData.isAirline.call(newAirline);
    // ASSERT
    assert.equal(isAirline, true, "Airline is registered with 1/2 consensus");

  });


});
