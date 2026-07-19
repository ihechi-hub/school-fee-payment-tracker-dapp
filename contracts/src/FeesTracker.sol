// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

contract FeeTracker {
    address public owner;
    
    // Define what a single payment looks like
    struct Payment {
        uint256 amount;
        uint256 timestamp;
    }
    
    // Each address => array of their payments
    mapping(address => Payment[]) public paymentHistory;
    
    // Keep totals for quick access (optional but handy)
    mapping(address => uint256) public totalPaid;
    mapping(address => uint256) public paymentCount;
    
    event PaymentMade(address indexed payer, uint256 amount, uint256 time, uint256 paymentId);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    function pay() external payable {
        require(msg.value > 0, "Send valid ETH");
        
        // Create and store the payment
        Payment memory newPayment = Payment({
            amount: msg.value,
            timestamp: block.timestamp
        });
        
        // Push to history
        paymentHistory[msg.sender].push(newPayment);
        
        // Update totals
        totalPaid[msg.sender] += msg.value;
        paymentCount[msg.sender]++;
        
        emit PaymentMade(
            msg.sender, 
            msg.value, 
            block.timestamp, 
            paymentCount[msg.sender] - 1  // Index of this payment
        );
    }
    
    // Get ALL payments for an address
    function getPaymentHistory(address student) 
        public 
        view 
        returns (Payment[] memory) {
                
        return paymentHistory[student];
    }
    
    // Get a specific payment by ID
    function getPayment(address student, uint256 paymentId) 
        public 
        view 
        returns (uint256 amount, uint256 timestamp) 
    {
        require(paymentId < paymentHistory[student].length, "Invalid ID");
        Payment memory p = paymentHistory[student][paymentId];
        return (p.amount, p.timestamp);
    }
    
    // Get latest payment
    function getLatestPayment(address student) 
        public 
        view 
        returns (uint256 amount, uint256 timestamp) 
    {
        uint256 count = paymentHistory[student].length;
        require(count > 0, "No payments");
        Payment memory p = paymentHistory[student][count - 1];
        return (p.amount, p.timestamp);
    }
    
    // Owner can withdraw
    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}