// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FeesTracker.sol";

contract FeeTrackerTest is Test {
    FeeTracker public feeTracker;
    address public owner;
    address public student1;
    address public student2;
    address public randomUser;
    
    uint256 constant INITIAL_BALANCE = 10 ether;
    
    // Declare the event for testing
    event PaymentMade(address indexed payer, uint256 amount, uint256 time, uint256 paymentId);
    
    function setUp() public {
        // Use actual addresses with balances
        owner = makeAddr("owner");
        student1 = makeAddr("student1");
        student2 = makeAddr("student2");
        randomUser = makeAddr("randomUser");
        
        // Fund all addresses
        vm.deal(owner, 100 ether);
        vm.deal(student1, 100 ether);
        vm.deal(student2, 100 ether);
        vm.deal(randomUser, 100 ether);
        
        vm.prank(owner);
        feeTracker = new FeeTracker();
    }
    
    // ============================================
    // CONSTRUCTOR TESTS
    // ============================================
    
    function test_Constructor() public view {
        assertEq(feeTracker.owner(), owner, "Owner should be deployer");
    }
    
    // ============================================
    // PAY() TESTS
    // ============================================
    
    function test_Pay_Success() public {
        uint256 paymentAmount = 1 ether;
        
        vm.prank(student1);
        feeTracker.pay{value: paymentAmount}();
        
        // Check total paid
        assertEq(feeTracker.totalPaid(student1), paymentAmount, "Total paid incorrect");
        assertEq(feeTracker.paymentCount(student1), 1, "Payment count incorrect");
        
        // Check history
        (uint256 amount, uint256 timestamp) = feeTracker.getPayment(student1, 0);
        assertEq(amount, paymentAmount, "Payment amount incorrect");
        assertEq(timestamp, block.timestamp, "Timestamp incorrect");
        
        // Check latest payment
        (uint256 latestAmount, ) = feeTracker.getLatestPayment(student1);
        assertEq(latestAmount, paymentAmount, "Latest payment incorrect");
    }
    
    function test_Pay_MultipleTimes() public {
        uint256 payment1 = 1 ether;
        uint256 payment2 = 2 ether;
        uint256 payment3 = 0.5 ether;
        
        vm.startPrank(student1);
        feeTracker.pay{value: payment1}();
        feeTracker.pay{value: payment2}();
        feeTracker.pay{value: payment3}();
        vm.stopPrank();
        
        // Check totals
        assertEq(feeTracker.totalPaid(student1), payment1 + payment2 + payment3, "Total incorrect");
        assertEq(feeTracker.paymentCount(student1), 3, "Count incorrect");
        
        // Check each payment
        (uint256 amt1, ) = feeTracker.getPayment(student1, 0);
        (uint256 amt2, ) = feeTracker.getPayment(student1, 1);
        (uint256 amt3, ) = feeTracker.getPayment(student1, 2);
        
        assertEq(amt1, payment1, "Payment 1 incorrect");
        assertEq(amt2, payment2, "Payment 2 incorrect");
        assertEq(amt3, payment3, "Payment 3 incorrect");
    }
    
    function test_Pay_ZeroAmount() public {
        vm.prank(student1);
        vm.expectRevert("Send valid ETH");
        feeTracker.pay{value: 0}();
    }
    
    function test_Pay_DifferentStudents() public {
        uint256 amount1 = 1 ether;
        uint256 amount2 = 2 ether;
        
        vm.prank(student1);
        feeTracker.pay{value: amount1}();
        
        vm.prank(student2);
        feeTracker.pay{value: amount2}();
        
        // Check student1
        assertEq(feeTracker.totalPaid(student1), amount1, "Student1 total incorrect");
        assertEq(feeTracker.paymentCount(student1), 1, "Student1 count incorrect");
        
        // Check student2
        assertEq(feeTracker.totalPaid(student2), amount2, "Student2 total incorrect");
        assertEq(feeTracker.paymentCount(student2), 1, "Student2 count incorrect");
        
        // Ensure they don't share data
        assertTrue(
            feeTracker.totalPaid(student1) != feeTracker.totalPaid(student2),
            "Students should have separate data"
        );
    }
    
    function test_Pay_EmitsEvent() public {
        uint256 paymentAmount = 1 ether;
        
        vm.prank(student1);
        
        // Expect the event
        vm.expectEmit(true, true, false, true);
        emit PaymentMade(student1, paymentAmount, block.timestamp, 0);
        
        feeTracker.pay{value: paymentAmount}();
    }
    
    function test_Pay_ContractBalance() public {
        uint256 paymentAmount = 1 ether;
        
        vm.prank(student1);
        feeTracker.pay{value: paymentAmount}();
        
        assertEq(address(feeTracker).balance, paymentAmount, "Contract balance incorrect");
    }
    
    // ============================================
    // GET PAYMENT HISTORY TESTS
    // ============================================
    
    function test_GetPaymentHistory_Empty() public view {
        FeeTracker.Payment[] memory history = feeTracker.getPaymentHistory(student1);
        assertEq(history.length, 0, "Should be empty");
    }
    
    function test_GetPaymentHistory_Success() public {
        uint256 paymentAmount = 1 ether;
        
        vm.prank(student1);
        feeTracker.pay{value: paymentAmount}();
        
        FeeTracker.Payment[] memory history = feeTracker.getPaymentHistory(student1);
        assertEq(history.length, 1, "Should have 1 payment");
        assertEq(history[0].amount, paymentAmount, "Amount incorrect");
        assertEq(history[0].timestamp, block.timestamp, "Timestamp incorrect");
    }
    
    function test_GetPaymentHistory_Multiple() public {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;
        amounts[2] = 0.5 ether;
        
        vm.startPrank(student1);
        for (uint i = 0; i < amounts.length; i++) {
            feeTracker.pay{value: amounts[i]}();
        }
        vm.stopPrank();
        
        FeeTracker.Payment[] memory history = feeTracker.getPaymentHistory(student1);
        assertEq(history.length, amounts.length, "Wrong history length");
        
        for (uint i = 0; i < amounts.length; i++) {
            assertEq(history[i].amount, amounts[i], "Amount mismatch");
        }
    }
    
    // ============================================
    // GET SPECIFIC PAYMENT TESTS
    // ============================================
    
    function test_GetPayment_Success() public {
        uint256 paymentAmount = 1 ether;
        
        vm.prank(student1);
        feeTracker.pay{value: paymentAmount}();
        
        (uint256 amount, uint256 timestamp) = feeTracker.getPayment(student1, 0);
        assertEq(amount, paymentAmount, "Amount incorrect");
        assertEq(timestamp, block.timestamp, "Timestamp incorrect");
    }
    
    function test_GetPayment_InvalidId() public {
        vm.prank(student1);
        feeTracker.pay{value: 1 ether}();
        
        vm.expectRevert("Invalid ID");
        feeTracker.getPayment(student1, 999);
    }
    
    function test_GetPayment_NoPayments() public {
        vm.expectRevert("Invalid ID");
        feeTracker.getPayment(student1, 0);
    }
    
    // ============================================
    // GET LATEST PAYMENT TESTS
    // ============================================
    
    function test_GetLatestPayment_Success() public {
        uint256 payment1 = 1 ether;
        uint256 payment2 = 2 ether;
        
        vm.startPrank(student1);
        feeTracker.pay{value: payment1}();
        feeTracker.pay{value: payment2}();
        vm.stopPrank();
        
        (uint256 amount, ) = feeTracker.getLatestPayment(student1);
        assertEq(amount, payment2, "Latest payment incorrect");
    }
    
    function test_GetLatestPayment_NoPayments() public {
        vm.expectRevert("No payments");
        feeTracker.getLatestPayment(student1);
    }
    
    // ============================================
    // WITHDRAW TESTS - FIXED
    // ============================================
    
    function test_Withdraw_Success() public {
        uint256 paymentAmount = 5 ether;
        
        // Student sends funds
        vm.prank(student1);
        feeTracker.pay{value: paymentAmount}();
        
        // Verify contract has funds
        uint256 contractBalance = address(feeTracker).balance;
        assertEq(contractBalance, paymentAmount, "Contract should have funds");
        
        // Owner withdraws
        vm.prank(owner);
        feeTracker.withdraw();
        
        // Contract should be empty
        assertEq(address(feeTracker).balance, 0, "Contract should be empty");
    }
    
    function test_Withdraw_EmptyContract() public {
        // Contract has 0 balance
        assertEq(address(feeTracker).balance, 0, "Contract should start empty");
        
        // Owner calls withdraw - should succeed (just transfers 0)
        vm.prank(owner);
        feeTracker.withdraw();
        
        // Contract should still be 0
        assertEq(address(feeTracker).balance, 0, "Contract should still be empty");
    }
    
    function test_Withdraw_NotOwner() public {
        // Student sends funds first
        vm.prank(student1);
        feeTracker.pay{value: 1 ether}();
        
        // Student tries to withdraw - should revert
        vm.prank(student1);
        vm.expectRevert("Not owner");
        feeTracker.withdraw();
    }
    
    function test_Withdraw_MultipleTimes() public {
        uint256 paymentAmount = 3 ether;
        
        // First deposit
        vm.prank(student1);
        feeTracker.pay{value: paymentAmount}();
        assertEq(address(feeTracker).balance, paymentAmount, "Balance after first deposit");
        
        // First withdrawal
        vm.prank(owner);
        feeTracker.withdraw();
        assertEq(address(feeTracker).balance, 0, "Balance after first withdrawal");
        
        // Second deposit
        vm.prank(student2);
        feeTracker.pay{value: paymentAmount}();
        assertEq(address(feeTracker).balance, paymentAmount, "Balance after second deposit");
        
        // Second withdrawal
        vm.prank(owner);
        feeTracker.withdraw();
        assertEq(address(feeTracker).balance, 0, "Balance after second withdrawal");
    }
    
    // ============================================
    // EDGE CASE TESTS
    // ============================================
    
    function test_Pay_MultipleUsers_MultiplePayments() public {
        uint256[] memory student1Payments = new uint256[](3);
        student1Payments[0] = 1 ether;
        student1Payments[1] = 2 ether;
        student1Payments[2] = 0.5 ether;
        
        uint256[] memory student2Payments = new uint256[](2);
        student2Payments[0] = 3 ether;
        student2Payments[1] = 1.5 ether;
        
        // Student 1 pays
        vm.startPrank(student1);
        for (uint i = 0; i < student1Payments.length; i++) {
            feeTracker.pay{value: student1Payments[i]}();
        }
        vm.stopPrank();
        
        // Student 2 pays
        vm.startPrank(student2);
        for (uint i = 0; i < student2Payments.length; i++) {
            feeTracker.pay{value: student2Payments[i]}();
        }
        vm.stopPrank();
        
        // Check student1 totals
        uint256 expectedTotal1 = 1 ether + 2 ether + 0.5 ether;
        assertEq(feeTracker.totalPaid(student1), expectedTotal1, "Student1 total incorrect");
        assertEq(feeTracker.paymentCount(student1), 3, "Student1 count incorrect");
        
        // Check student2 totals
        uint256 expectedTotal2 = 3 ether + 1.5 ether;
        assertEq(feeTracker.totalPaid(student2), expectedTotal2, "Student2 total incorrect");
        assertEq(feeTracker.paymentCount(student2), 2, "Student2 count incorrect");
        
        // Check contract balance
        assertEq(address(feeTracker).balance, expectedTotal1 + expectedTotal2, "Balance incorrect");
    }
    
    // ============================================
    // FUZZ TESTS
    // ============================================
    
    function test_Pay_Fuzz(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount < 1000 ether);
        
        vm.deal(student1, amount);
        vm.prank(student1);
        feeTracker.pay{value: amount}();
        
        assertEq(feeTracker.totalPaid(student1), amount, "Total incorrect");
        assertEq(feeTracker.paymentCount(student1), 1, "Count incorrect");
        
        (uint256 paidAmount, ) = feeTracker.getPayment(student1, 0);
        assertEq(paidAmount, amount, "Payment amount incorrect");
    }
}