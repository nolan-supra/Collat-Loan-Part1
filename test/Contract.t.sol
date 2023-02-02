// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "src/Contract.sol";

contract TestContract is Test {
    Contract c;
    address usdc;
    address userAdr;
    uint testAmount;

    bool loaned;
    uint deposited;
    uint loan;
    uint interest;

    function setUp() public {
        userAdr = address(1337);
        testAmount = 1 ether;

        usdc = 0x2f3A40A3db8a7e3D09B0adfEfbCe4f6F81927557;
        c = new Contract(usdc, 0x25DfdeD39bf0A4043259081Dc1a31580eC196ee7);
    }

    //Test for depositEther()
    function testDeposit() public {
        vm.startPrank(userAdr);
        deal(userAdr, testAmount);

        c.depositEther{value: testAmount}();
        (loaned, deposited, loan, interest) = c.getLoanDetails();
        
        //Check balance of ether 
        assertEq(testAmount, deposited);
    }

    //Test for depositEther()
    function testDeposit_ActiveLoan() public {
        vm.startPrank(userAdr);

        deal(userAdr, testAmount * 2);
        deal(usdc, address(c),  testAmount);

        c.depositEther{value: testAmount}();
        c.withdrawUsdc();

        vm.expectRevert();
        c.depositEther{value: testAmount}();
    }

    //Test for depositEther()
    function testDeposit_LessThanMinimum() public {
        vm.startPrank(userAdr);

        deal(userAdr, testAmount);

        vm.expectRevert();
        c.depositEther{value: testAmount}();
    }

    function testBar() public {
        uint amount = 1 ether;
        //deposits $1000 USDC
        deal(usdc, address(c),  amount);
        //deal(usdc, 0x4dd64440d6b2d52f07A095cd26e911551D8e5958, 5);
        address userAdr = address(1337);
        //prank for approves spending
        //vm.prank(0x4dd64440d6b2d52f07A095cd26e911551D8e5958);
        //approves spending
        //IERC20(usdc).approve(address(c), 5);

        //deposits ETHER
        //vm.prank(address(1));

        //deposits 1 ether
        deal(userAdr, amount);
        //console.log('Before loan:');
        //printMe(userAdr);

        vm.startPrank(userAdr);
        bool a;
        uint aa;
        uint aaa;
        uint aaaa;

        //console.log('USER ETHER Balance %s', userAdr.balance);
        //console.log('CONTRACT ETHER Balance %s', address(c).balance);

        (a, aa, aaa, aaaa) = c.getLoanDetails();
        //console.log(a);
        //console.log('%s \t %s \t %s\n', aa, aaa, aaaa);
        //console.log('USER USDC Balance: %s', IERC20(usdc).balanceOf(userAdr));
        c.depositEther{value: amount}();
        (a, aa, aaa, aaaa) = c.getLoanDetails();
        //console.log(a);
        //console.log('%s \t %s \t %s\n', aa, aaa, aaaa);

        //console.log('CONTRACT USDC Balance: %s', IERC20(usdc).balanceOf(address(c)));
        c.withdrawUsdc();

        //console.log('USER ETHER Balance %s', userAdr.balance);
        //console.log('CONTRACT ETHER Balance %s', address(c).balance);


        //console.log('CONTRACT USDC Balance: %s', IERC20(usdc).balanceOf(address(c)));
        //console.log('USDC Balance: %s', IERC20(usdc).balanceOf(userAdr));
        (a, aa, aaa, aaaa) = c.getLoanDetails();
        //console.log(a);
        //console.log('%s \t %s \t %s\n', aa, aaa, aaaa);
        


        deal(usdc, address(userAdr),  aaa+aaaa);
        IERC20(usdc).approve(address(c), aaa+aaaa);
        
        //console.log('USDC Balance: %s', IERC20(usdc).balanceOf(userAdr));
        c.payOff();
        //console.log('CONTRACT USDC Balance: %s', IERC20(usdc).balanceOf(address(c)));
        //console.log('USDC Balance: %s', IERC20(usdc).balanceOf(userAdr));
        (a, aa, aaa, aaaa) = c.getLoanDetails();
        //console.log(a);
        //console.log('%s \t %s \t %s\n', aa, aaa, aaaa);
        //console.log('\n\nAfter loan:');
        //printMe(userAdr);
        //assertGt(two, 0);
        
        //console.log('USER ETHER Balance %s', userAdr.balance);
        //console.log('CONTRACT ETHER Balance %s', address(c).balance);
    }

    function testFuzz(uint96 amount) public {
        //uint amount = 1 ether;

        vm.assume(amount >= 0.1 ether);
        //deposits $1000 USDC
        deal(usdc, address(c),  amount);
        //deal(usdc, 0x4dd64440d6b2d52f07A095cd26e911551D8e5958, 5);

        address userAdr = address(1337);
        //prank for approves spending
        //vm.prank(0x4dd64440d6b2d52f07A095cd26e911551D8e5958);
        //approves spending
        //IERC20(usdc).approve(address(c), 5);

        //deposits ETHER
        //vm.prank(address(1));

        //deposits 1 ether
        deal(userAdr, amount);
        //console.log('Before loan:');
        //printMe(userAdr);

        vm.startPrank(userAdr);

        c.depositEther{value: amount}();
        c.withdrawUsdc();
        c.getLoanDetails();

        //console.log('\n\nAfter loan:');
       //printMe(userAdr);
        //assertGt(two, 0);
    }

   function printMe(address userAdr) public{
        console.log('----------------------------------');
        console.log('CONTRACT \n\tUSDC:\t%s',IERC20(usdc).balanceOf(address(c)));
        console.log('\tETHER:\t%s',address(c).balance);

        console.log('WALLET \n\tUSDC:\t%s',IERC20(usdc).balanceOf(address(userAdr)));
        console.log('\tETHER:\t%s',address(userAdr).balance);
        console.log('----------------------------------');
   }

}
