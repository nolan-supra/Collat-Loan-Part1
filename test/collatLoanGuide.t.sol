// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "src/collatLoanGuide.sol";

contract TestContract is Test {
    collatLoanGuide c;
    address usdc;
    address supraAddress;
    address userAdr;
    uint96 testAmount;

    bool loaned;
    uint deposited;
    uint depositedAvailable;
    uint loan;
    uint interest;

    function setUp() public {
        userAdr = address(1337);
        //default testAmount -- shadowed by fuzz tests
        testAmount = 1 ether;

        //Goerli Eth USDC Contract
        usdc = 0x2f3A40A3db8a7e3D09B0adfEfbCe4f6F81927557;
        //Goerli Eth SupraOracles S-Value Price Feed Contract
        supraAddress = 0x25DfdeD39bf0A4043259081Dc1a31580eC196ee7;

        c = new collatLoanGuide(usdc, supraAddress);

        vm.startPrank(userAdr);
    }


    //Test default deposit
    function testDeposit(uint96 testAmount) public {
        vm.assume(testAmount >= c.minimumLoan());

        deal(userAdr, testAmount);

        c.depositEther{value: testAmount}();
        (loaned, deposited, depositedAvailable, loan, interest) = c.getLoanDetails();
        
        //Check balance of ether 
        assertEq(testAmount, deposited);
    }

    //Test multiple deposits in a row
    function testDeposit_MultipleDeposit(uint96 testAmount, uint8 ii) public{
        vm.assume(testAmount >= c.minimumLoan());
        vm.assume(ii > 2);
        for(uint i = 1; i < ii; i++){
            deal(userAdr, testAmount);
            c.depositEther{value: testAmount}();
            (loaned, deposited, depositedAvailable, loan, interest) = c.getLoanDetails();
            assertEq(testAmount*i, deposited);
        }
    }

    //Test deposit with less than minimum required ether
    function testDeposit_LessThanMin(uint96 testAmount) public {
        vm.assume(testAmount < c.minimumLoan());
        deal(userAdr, testAmount);

        vm.expectRevert();
        c.depositEther{value: testAmount}();
    }

    //Test deposit when user already took loan
    function testDeposit_AfterWithdrawLoan() public {
        deal(userAdr, testAmount * 2);
        deal(usdc, address(c),  testAmount);

        c.depositEther{value: testAmount}();
        c.withdrawLoan(testAmount);
        c.depositEther{value: testAmount}();
    }

    //Test withdraw of USDC after deposit
    function testwithdrawLoan(uint96 testAmount) public{
        testDeposit(testAmount);
        deal(usdc, address(c),  testAmount);
        c.withdrawLoan(testAmount);
        (loaned, deposited, depositedAvailable, loan, interest) = c.getLoanDetails();
        assertEq(loan, IERC20(usdc).balanceOf(userAdr));
    }

    //Test withdraw of USDC with an active loan (Withdraw after already withdrawn)
    function testwithdrawLoan_ActiveLoan(uint96 testAmount) public{
        testDeposit(testAmount);
        deal(usdc, address(c),  testAmount);
        c.withdrawLoan(testAmount);

        vm.expectRevert();
        c.withdrawLoan(testAmount);
    }

    //Test withdraw with no deposit sent
    function testwithdrawLoan_NoMinDeposit() public{
        //testDeposit(testAmount);
        deal(usdc, address(c),  testAmount);
        vm.expectRevert();
        c.withdrawLoan(testAmount);
    }

    //Test withdraw with not enough USDC in smart contract
    function testwithdrawLoan_LowUsdc() public{
        testDeposit(testAmount);
        vm.expectRevert();
        c.withdrawLoan(testAmount);
    }

    //Test calculate loan amount and interest (unit conversion from WEI to USDC)
    function testCalculateUsdc_Fuzz(uint96 testAmount) public {
        (uint amount, uint interest) = c.calculateUsdc(testAmount);
        assertGe(amount, interest);
    }

    //Test calculate loan amount and interest for single value
    function testCalculateUsdc_Single() public{
        //change this value :thumbs up:
        //testAmount = .5 ether;
        (uint amount, uint interest) = c.calculateUsdc(testAmount);
        //console.log('Amount: %s\tInterest: %s\tTotal: %s',amount, interest, amount+interest);
        assertGe(amount, interest);
    }

    //Test the pay off of a loan
    function testPayOff(uint96 testAmount) public {
        testwithdrawLoan(testAmount);
        deal(usdc, userAdr,  loan+interest);
        IERC20(usdc).approve(address(c), loan+interest);
        c.payOff();
    }

    //test pay off when no loan exists
    function testPayOff_NoLoan() public {
        vm.expectRevert();
        c.payOff();
    }

    //test pay off when not enough allowance set
    function testPayOff_LowAllowance(uint96 testAmount) public {
        testwithdrawLoan(testAmount);
        IERC20(usdc).approve(address(c), (loan+ interest - 1));
        vm.expectRevert();
        c.payOff();
    }

    //test withdraw of ether when no deposit has been made
    function testWithdrawEther_NoDeposit() public{
        vm.expectRevert();
        c.withdrawEther(testAmount);
    }

    //test withdraw of ether when a deposit has been made and a loan hasn't been taken
    function testWithdrawEther_DepositNoLoan(uint96 testAmount) public{
        testDeposit(testAmount);
        c.withdrawEther(testAmount);
        assertEq(deposited, userAdr.balance);
    }

    //test withdraw when a deposit has been made and a loan has been taken
    function testWithdrawEther_DepositLoan(uint96 testAmount) public{
        testwithdrawLoan(testAmount);
        vm.expectRevert();
        c.withdrawEther(testAmount);
    }

    //test withdraw after withdraw has been made
    function testWithdrawEther_Multiple(uint96 testAmount) public{
        testWithdrawEther_DepositNoLoan(testAmount);
        vm.expectRevert();
        c.withdrawEther(testAmount);
    }

    //test withdraw when not enough ether in smart contract
    function testWithdrawEther_NoEtherInContract(uint96 testAmount) public{
        testDeposit(testAmount);
        deal(address(c), 0);
        vm.expectRevert();
        c.withdrawEther(testAmount);
    }

    function testNew() public{
        //test deposit
        /*testDeposit(testAmount);
        console.log(deposited, depositedAvailable, loan, interest);
        console.log('\n');

        deal(usdc, address(c),  testAmount);

        c.withdrawLoan(testAmount/2);
        (loaned, deposited, depositedAvailable, loan, interest) = c.getLoanDetails();
        console.log(deposited, depositedAvailable, loan, interest);
        console.log('\n');

        deal(usdc, userAdr,  loan+interest);
        IERC20(usdc).approve(address(c), loan+interest);
        c.payOff();

        (loaned, deposited, depositedAvailable, loan, interest) = c.getLoanDetails();
        console.log(deposited, depositedAvailable, loan, interest);
        console.log('\n');*/
    }

}
