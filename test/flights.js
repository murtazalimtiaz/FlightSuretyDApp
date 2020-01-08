
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  const SEED_FUND = web3.utils.toWei("10", "ether")
  const FLIGHTS = {
    'NYC': {
      airline: accounts[1],
      flight: 'NYC',
      timestamp: Date.now() - 250000
    },
    'LHR': {
      airline: accounts[2],
      flight: 'LHR',
      timestamp: Date.now() + 250000
    }
  }
  before('setup contract', async () => {
    config = await Test.Config(accounts)
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address)

    let newAirline = FLIGHTS.NYC.airline
    let balance = await config.flightSuretyData.getContractBalance.call();
    printEth('Contract balance is : ', balance);
    await config.flightSuretyApp.fundAirline({ from: config.owner, value: SEED_FUND, gasPrice: 0 })
    balance = await config.flightSuretyData.getContractBalance.call();
    printEth('Contract balance is : ', balance);
    //await config.flightSuretyApp.registerAirline(newAirline, { from: config.firstAirline });
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(flights) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(flights) airlines can register new flights`, async function () {

    let flight = FLIGHTS.NYC;

    await config.flightSuretyData.registerFlight(flight.airline, flight.flight, flight.timestamp);

    let result = await config.flightSuretyData.isFlightRegistered(flight.airline, flight.flight, flight.timestamp);


    assert.equal(result, true, "Flight should be registered");

  });


  it(`(flights) airlines cannot register flight twice `, async function () {

    let flight = FLIGHTS.NYC;
    let accessDenied = false;
    try {
      await config.flightSuretyData.registerFlight(flight.airline, flight.flight, flight.timestamp);
    }
    catch (e) {
      accessDenied = true;
    }
    assert.equal(accessDenied, true, "This Flight is already registered");

  });

  it(`(flights) Unregistered airlines cannot register flight`, async function () {

    let flight = FLIGHTS.LHR;
    let accessDenied = false;
    try {
      await config.flightSuretyData.registerFlight(flight.airline, flight.flight, flight.timestamp);
    }
    catch (e) {
      console.log(e.message);
      accessDenied = true;
    }
    assert.equal(accessDenied, true, "Cannot register filght : Airline is not registered");

  });

  it('(passengers) Passengers cannot select non-registered flight', async function () {
    let flight = FLIGHTS.LHR;
    let passenger = accounts[11];
    let insurance = web3.utils.toWei("0", 'ether');
    let accessDenied = false;
    try {
      await config.flightSuretyData.buyInsurance(flight.airline, flight.flight, flight.timestamp, { from: passenger, value: insurance });
    }
    catch (e) {
      console.log(e.message);
      accessDenied = true;
    }
    assert.equal(accessDenied, true, "Cannot select this flight : Flight is not registered");
  });

  it('(passengers) Passengers cannot purchase insurance without funds', async function () {
    let flight = FLIGHTS.NYC;
    let passenger = accounts[11];
    let insurance = web3.utils.toWei("0", 'ether');
    let accessDenied = false;
    try {
      await config.flightSuretyData.buyInsurance(flight.airline, flight.flight, flight.timestamp, { from: passenger, value: insurance });
    }
    catch (e) {
      console.log(e.message);
      accessDenied = true;
    }
    assert.equal(accessDenied, true, "Passengers canot purchase insurance without funds");
  });

  it('(passengers) Passengers cannot purchase insurance beyond limits', async function () {
    let flight = FLIGHTS.NYC;
    let passenger = accounts[11];
    let insurance = web3.utils.toWei("1", 'ether') + 1;
    let accessDenied = false;
    try {
      await config.flightSuretyData.buyInsurance(flight.airline, flight.flight, flight.timestamp, { from: passenger, value: insurance });
    }
    catch (e) {
      console.log(e.message);
      accessDenied = true;
    }
    assert.equal(accessDenied, true, "Passengers canot purchase insurance beyond limits");
  });

  it('(passengers) Passengers can purchase insurance', async function () {
    let flight = FLIGHTS.NYC;
    let passenger = accounts[11];
    let insurance = web3.utils.toWei("1", 'ether');

    await config.flightSuretyData.buyInsurance(flight.airline, flight.flight, flight.timestamp, { from: passenger, value: insurance });

    let amount = await config.flightSuretyData.getInsuranceAmount.call({ from: passenger });
    printEth('Insurance amount : ' , amount);
    assert.equal(amount, insurance, "Insurance amount not matching with purchased amount");
  });


  it('(Insurance) Insurance amount is credited by 1.5 x', async function () {
    let flight = FLIGHTS.NYC;
    let passenger = accounts[11];
    let insurance = web3.utils.toWei("1", 'ether')
    var newAmount = 1 + (1 * 1.5);
    let expected = web3.utils.toWei(newAmount.toString(), 'ether');

    try {
      await config.flightSuretyApp.creditInsuree(passenger, flight.airline);
    } catch (e) {
      console.log(e)
    }

    let amount = await config.flightSuretyData.getInsuranceAmount.call({ from: passenger });
    printEth('New Insurance amount : ', amount);
    assert.equal(amount, expected, "Insurance amount not increased as expected by 1.5x");
  });


  it('(Passenger) Passengers can withdraw amount', async function () {
    let flight = FLIGHTS.NYC;
    let passenger = accounts[11];

    let withdrawAmount = web3.utils.toWei("1", 'ether')

    const prevBalance = await web3.eth.getBalance(passenger)
    printEth('Prev balance : ', prevBalance)

    try {
      await config.flightSuretyApp.withdraw(passenger, withdrawAmount, { from: config.owner, gasPrice: 0 });
    } catch (e) {
      console.log(e.message)
    }
    const newBalance = await web3.eth.getBalance(passenger)

    console.log('Diff ' + (newBalance - prevBalance));

    assert.equal((newBalance - prevBalance), 0, "Account balance is not increased as expected");
  });

  function printEth(label, amount) {
    console.log(label + ' : ' + web3.utils.fromWei(amount.toString(), 'ether') + ' ether')
  }


});
