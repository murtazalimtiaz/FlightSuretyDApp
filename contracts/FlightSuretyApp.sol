pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
//import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract
    FlightSuretyData flightDataContract;

    mapping(address => address[]) airlineVotes;

    uint constant AIRLINES_THRESHOLD = 3;
    uint public constant SEED_FUNDING = 10 ether;

    /********************************************************************************************/
    /*                                       EVENTS DEFINITIONS                                 */
    /********************************************************************************************/
    event AirlineRegistered(
        address indexed airline,
        uint votes,
        uint totalAirlines
    );

    event AirlineFunded(
        address indexed airline,
        uint fund
    );

    
    event FlightRegistered(
        address indexed airline,
        string flight,
        uint256 timestamp
    );
 
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
         // Modify to call data contract's status
        require(true, "Contract is currently not operational");  
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

    modifier requireFunded(address airline) {
        require(flightDataContract.isAirlineFunded(airline), "Airline is not funded");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
    (
        address dataContract,
        address firstAirline
    ) 
    public 
    {
        contractOwner = msg.sender;
        log0("Data contract : ");
        flightDataContract = FlightSuretyData(dataContract);
        // Register first airline
        registerAirline(firstAirline);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
    public 
    view 
    returns(bool) 
    {
        return flightDataContract.isOperational();
    }

    function setOperatingStatus
    (
        bool mode
    ) 
    external
    requireContractOwner
    {
        flightDataContract.setOperatingStatus(mode);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline
    (   
        address airline
    )
    public
    requireFunded(msg.sender)
    returns(bool success, uint256 votes, uint256 totalAirlines)
    {
        require(airline != address(0), "Invalid address of first airline");

        address[] memory airlines = flightDataContract.getActiveAirlines();
        if (airlines.length == 0 ) {
            // First airline
            flightDataContract.registerAirline(airline);
        } else if (airlines.length < AIRLINES_THRESHOLD) {
            // Only existing airlines can register new airlines
            require(flightDataContract.isAirline(msg.sender), "Only existing airlines can register new airline");
            flightDataContract.registerAirline(airline);    
        } else {
            // Cast airline votes
            bool isDuplicate = false;
            for(uint8 i = 0; i < airlineVotes[airline].length; i++) {
                if (airlineVotes[airline][i] == msg.sender) {
                    isDuplicate = true;
                    break;
                }
            }
            require(!isDuplicate, "Duplicate votes are not allowed");
            airlineVotes[airline].push(msg.sender);
            // If votes are sufficient then register ailine
            if (airlineVotes[airline].length > airlines.length.div(2)) {
                flightDataContract.registerAirline(airline);
                // Reset voting process for this airline
                airlineVotes[airline] = new address[](0);
            }
        }

        emit AirlineRegistered(airline, airlineVotes[airline].length, airlines.length);
        return (true, airlineVotes[airline].length, airlines.length);
    }

    function getVotes(address airline) external view returns (address[] memory) {
        return airlineVotes[airline];
    }

    /** Get airlines*/
    function getActiveAirlines() external view returns(address[] memory)
    {
        return flightDataContract.getActiveAirlines();
    }

    /**
    * @dev Fund airline by transffering value to contract address using debit first approach
    *
    */   
    function fundAirline
    (
    )
    public
    payable
    {
        require(msg.value >= SEED_FUNDING, "Not sufficient fund sent");
        // Credit airline balance
        flightDataContract.fundAirline.value(SEED_FUNDING)(msg.sender);
        emit AirlineFunded(msg.sender, msg.value);
    }

    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
    (
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    )
    internal
    {
        flightDataContract.processFlightStatus(airline, flight, timestamp, statusCode);
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
    (
        address airline,
        string flight,
        uint256 timestamp                            
    )
    external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({requester: msg.sender,isOpen: true});

        emit OracleRequest(index, airline, flight, timestamp);
    } 

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
    requireFunded(airline)
    requireIsOperational
    {
        require(flightDataContract.isAirline(airline), "Airline is not registered for flights");

        flightDataContract.registerFlight(airline, flight, timestamp);
        emit FlightRegistered(airline, flight, timestamp);
    }


    function buyInsurance
    (
        address airline,
        string flight,
        uint256 timestamp
    ) 
    external
    payable
    {
        flightDataContract.buyInsurance.value(msg.value)(airline, flight, timestamp);
    }


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status, uint8 index);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 statusCode);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
    (
    )
    external
    payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({isRegistered: true,indexes: indexes});
    }

    function getMyIndexes
    (
    )
    view
    external
    returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
    (
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode
    )
    external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {
            
            // Close accepting status to prevent emitting events
            oracleResponses[key].isOpen = false;

            emit FlightStatusInfo(airline, flight, timestamp, statusCode, index);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
    (
        address airline,
        string flight,
        uint256 timestamp
    )
    pure
    internal
    returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
    (                       
        address account         
    )
    internal
    returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
    (
        address account
    )
    internal
    returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   


contract FlightSuretyData {
    function isOperational() public view returns(bool);
    function setOperatingStatus(bool mode) external;

    function isAirline(address airline) external view returns(bool); 
    function isAirlineFunded(address airline) external view returns(bool);

    function registerAirline(address airline) public;
    function fundAirline(address airline) public payable;
    function getActiveAirlines() external view returns(address[] memory);

    function registerFlight(address airline, string flight, uint256 timestamp) public;
    function isFlightRegistered(address airline, string flight, uint256 timestamp) public view returns(bool);
    function processFlightStatus(address airline, string flight, uint256 timestamp, uint8 statusCode) external;

    function buyInsurance(address airline, string flight, uint256 timestamp) external payable;
    function creditInsurees(address passenger, address airline) external;
    
}