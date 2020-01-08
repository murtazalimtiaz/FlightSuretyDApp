pragma solidity ^0.4.25;
pragma experimental ABIEncoderV2;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    // Mapping to track authorized AppContracts
    mapping(address => bool) private authorizedCallers;
    // Mapping to track voters of operational status

    /************ All airlines ***************************************/ 
    mapping(address => Airline) private airlines;
    address[] activeAirlines = new address[](0);

    struct Airline {
        address airline;
        bool isFunded;
        bool isRegistered;
    }

    struct Flight {
        address airline;
        string flight;
        uint256 timestamp;
        bool isRegistered;
        address[] passengers;
    }

    struct FlightInsurance {
        address airline;
        uint256 insurance;
    }

    mapping(bytes32 => Flight) flights; // All registered flights

    mapping(address => FlightInsurance) insurance;

    uint256 constant MAX_INSURANCE = 1 ether;


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event InsuranceCredited(
        address passenger,
        uint256 insurance
    );

    event AmountTransfered(
        address passenger,
        uint256 amount
    );

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
    (
    ) 
    public
    payable
    {
        contractOwner = msg.sender;
        contractOwner.transfer(msg.value);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }


    /**
    *@dev Modifier that check if airline mapping exists or not
    */
    modifier requireRegisteredAirline(address airline)
    {
        require(airline != address(0), "Airline is not registered-0");
        address tempAddress = airlines[airline].airline;
        require(tempAddress != address(0), "Airline is not registered-1");
        _;
    }

    /**
    *@dev Modifier that check if caller is authorized
    */
    modifier requireAuthorizedCaller(address caller)
    {
        require(authorizedCallers[caller], "Caller is not authorized");
        _;
    }

    modifier requireFlightRegistered(address airline, string memory flight, uint256 timestamp)
    {
        require(isFlightRegistered(airline, flight, timestamp), "Flight does not exists");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
    public 
    view 
    returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
    (
        bool mode
    ) 
    external
    requireContractOwner
    {
        require(operational != mode, "Operational status should be different from current status");
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
    (   
        address airline
    )
    public
    requireIsOperational
    {
        require(!airlines[airline].isRegistered, "Airline is already registered");
        airlines[airline] = Airline(airline, false, true);
        activeAirlines.push(airline);
        //return airlines[airline].isRegistered;
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fundAirline
    (
        address airline
    )
    public
    payable
    {
        // Credit airline balance
        airlines[airline].isFunded = true;
        // Transfer amount to contract address
        contractOwner.transfer(msg.value);
    }

    /**
    * Utility functions
    */

    function authorizeCaller(address contractAddress) external requireContractOwner
    {
        authorizedCallers[contractAddress] = true;
    }

    function deAuthorizeCaller(address contractAddress) external requireContractOwner
    {
        delete authorizedCallers[contractAddress];
    }

    /** Check if airline is present */
    function isAirline(address airline) external view returns(bool) {
        return (airlines[airline].airline != address(0));
    }


    /** Get Airline isFunded */
    function isAirlineFunded(address airline) external view returns(bool)
    {
        if (activeAirlines.length == 0) {
            // let first airline pass
            return true;
        }
        return airlines[airline].isFunded;
    }

    /** Get Airline balance */
    function getActiveAirlines() external view returns(address[] memory)
    {
        return activeAirlines;
    }

    /************ All flights ****************************************/ 

   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight
    (
        address airline,
        string flight,
        uint256 timestamp
    )
    public
    requireIsOperational
    requireRegisteredAirline(airline)
    {
        bytes32 key = getFlightKey(airline, flight, timestamp);
        require(!flights[key].isRegistered, "Flight is already registered");
        address[] memory passengers = new address[](0);
        flights[key] = Flight(airline, flight, timestamp, true, passengers);
    }

      /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
    (
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode
    )
    external
    requireIsOperational
    requireRegisteredAirline(airline)
    {
        bytes32 key = getFlightKey(airline, flight, timestamp);
        address[] memory passengers = flights[key].passengers;
        require(passengers.length > 0, "No passenger baught insurance yet....");
        for(uint8 i = 0; i < passengers.length; i++) {
            creditInsuree(passengers[i], airline);
        }
    }


    function buyInsurance
    (
        address airline,
        string flight,
        uint256 timestamp
    ) 
    external
    payable
    requireFlightRegistered(airline, flight, timestamp)
    {
        require(msg.value > 0 && msg.value <= MAX_INSURANCE, "Insurance limits not matched");
        bytes32 key = getFlightKey(airline, flight, timestamp);
        flights[key].passengers.push(msg.sender);
        insurance[msg.sender] = FlightInsurance(airline, msg.value);
    }

    /** Credit insurees if flight is delay*/
    function creditInsuree
    (
        address passenger,
        address airline
    ) 
    public
    requireAuthorizedCaller(msg.sender)
    payable
    {
        uint256 insuranceAmount = insurance[passenger].insurance;
        require(insuranceAmount > 0, "Passenger haven't bought insurance");
        require(airline != address(0), "Airline doesn't exists");

        // Apply insurance policy
        uint256 refundAmount = insuranceAmount.mul(15).div(10); // 1.5x
        insurance[passenger].insurance = insurance[passenger].insurance.add(refundAmount);

        emit InsuranceCredited(passenger, insurance[passenger].insurance);
    }


    /**
     *  @dev Passengers can withdraw amount to their accounts
     *
    */
    function withdraw
    (
        address passenger,
        uint256 amount
    )
    external
    requireAuthorizedCaller(msg.sender)
    payable
    {
        uint256 insuranceAmount = insurance[passenger].insurance;
        require(amount <= insuranceAmount, "Insufficient balance to withdraw");

        // Debit first approach
        insurance[passenger].insurance = insurance[passenger].insurance.sub(amount);
        // Transfer amount to account
        passenger.transfer(insuranceAmount);

        emit AmountTransfered(passenger, insuranceAmount);
    }

    function getInsuranceAmount() public view returns (uint256){
        return insurance[msg.sender].insurance;
    }

    function getContractBalance() external view returns (uint256 balance) {
        return contractOwner.balance;
    }


    function getFlightKey
    (
        address airline,
        string memory flight,
        uint256 timestamp
    )
    internal
    pure
    returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    function isFlightRegistered
    (
        address airline,
        string flight,
        uint256 timestamp
    )
    public
    view 
    returns(bool) 
    {
        bytes32 key = getFlightKey(airline, flight, timestamp);
        return flights[key].isRegistered;
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
    external 
    payable 
    {
        contractOwner.transfer(msg.value);
    }


}

