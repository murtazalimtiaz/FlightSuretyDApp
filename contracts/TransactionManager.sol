pragma solidity >=0.4.22 <0.6.0;

// It is the first block
// Transaction manager manages all transactions
contract TransactionManager {

    address private contractOwner;          // Account used to deploy contract

    // Super Commodity class
    struct Commodity {
        //data types goes here
    }

    mapping(address => Commodity[]) stockCommodities;
    mapping(address => Commodity[]) userCommodities;

    constructor
    (
        address dataContract,
        address firstTransaction
    )
    public
    {
        contractOwner = msg.sender;
        log0("Data contract : ");
        transactionData = TransactionData(dataContract);

    }
}