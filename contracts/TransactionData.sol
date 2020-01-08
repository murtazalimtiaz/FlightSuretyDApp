pragma solidity >=0.4.22 <0.6.0;

contract TransactionData {

    address private contractOwner;                                      // Account used to deploy contract

    constructor
    (
    )
    public
    payable
    {
        contractOwner = msg.sender;
        contractOwner.transfer(msg.value);
    }
}