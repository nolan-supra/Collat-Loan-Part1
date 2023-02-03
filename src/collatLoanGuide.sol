// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

//OpenZeppelin IERC20.sol :: https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#IERC20
//                        :: Interface for interacting with ERC20 tokens conforming to the ERC20 standard.
//                        :: Used to transfer ERC20 USDC tokens to and from the user for loans and loan payoff.
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//SupraOracles ISupraSValueFeed.sol :: https://supraoracles.com/docs/get-started
//                                  :: Interface for interacting with SupraOracles S-Value Price Feed.
//                                  :: Used to obtain the latest price data for the ETH/USDT pair for unit conversion.
import "./ISupraSValueFeed.sol";

//Contract :: Collateral Loan Guide Part 1
//Includes functionality for :: Deposit Collateral, Withdraw Loan, Unit Conversion (WEI <-> USDC), Pay Off Loan
contract collatLoanGuide {

    //--- VARIABLES ---\\

    //Instance of IERC20 interface to interact with USDC smart contract.
    IERC20 internal usdc;
    //Instance of ISupraSValueFeed interface to interact with SupraOracles S-Value price feed.
    ISupraSValueFeed internal sValueFeed;
    //Percentage used to calculate available loan.
    uint public loanPercentage;
    //Percentage used to calculate fee.
    uint public feePercentage;
    //Minimum amount of ether to be loaned/deposited.
    uint public minimumLoan;

    //Mapping of users address to loanDetails struct. Holds loan data for each user.
    mapping(address => loanDetails) public loanMap;

    //Struct for loan details
    struct loanDetails {
        uint deposited; //Total amount of ether (WEI) that the user has deposited for their loan.
        uint depositedAvailable; //Amount of deposited ether that is available/has not been used.
        uint loan;      //Amount of USDC that the user has withdrawn for their loan.
        uint fee;  //Amount of fee that the user must pay in addition to the original loan amount.
    }
    
    //--- FUNCTIONS ---\\
 
    /*
    *   constructor(address usdcAddress, address supraAddress)
    *               param1  :   address usdcAddress    -   Used to interact with the USDC contract through the IERC20 interface
    *               param2  :   address supraAddress   -   Used to interact with the SupraSValueFeed contract through the ISupraSValueFeed interface
    *               bio     :   Called once upon contract deployment.
    *                           Set USDC/SupraSValueFeed interfaces and values
    */
    constructor(address usdcAddress, address supraAddress){
        //----Interfaces----\\
        //Binds the usdcAddress to the IERC20 interface
        usdc = IERC20(usdcAddress);
        //Binds the supraAddress to the ISupraSValueFeed interface
        sValueFeed = ISupraSValueFeed(supraAddress);

        //----Values----\\
        //Set the loan percenage to 80%.
        loanPercentage = 80;
        //Set the fee percenage to 10%.
        feePercentage = 10;
        //Set the minimum loan/deposit allowed to .1 ether.
        minimumLoan = .1 ether;
    }

    /*
    *   depositEther() extrenal payable
    *               bio     :   Payable function that allows a user to deposit ether to the contract.
    *                           Requires the sent ether to be >= the set minimum deposit value.
    *                           User can make multiple deposits.
    */
    function depositEther() external payable{
        //Only allow deposits that are >= the set minimumLoan amount.
        require(msg.value >= minimumLoan, 'Not enough ether sent.');

        //Update the amount of ether that the user has deposited and has available.
        //By += the deposited amount, we enable the user to make multiple deposits before taking out a loan.
        loanMap[msg.sender].deposited += msg.value;
        loanMap[msg.sender].depositedAvailable += msg.value;
    } 

    /*
    *   withdrawLoan(uint loanAmount) external
    *               param1  :   uint loanAmount         -   Amount of available ether to take the loan against.
    *               bio     :   Function that allows the user to withdraw USDC (take the loan) dependent on their deposited available amount.
    *                           Requires the user to have available ether >= the minimum loan amount.
    *                           Requires the user to have enough available ether for the requested amount.
    *                           Updates the loan details associated with the user's address
    *                           Transfers the USDC loan to the user's address.
    */
    function withdrawLoan(uint loanAmount) external {
        //Only allow withdraws for users that have deposited enough ether.
        require(loanMap[msg.sender].depositedAvailable >= minimumLoan, 'Not enough ether deposited.');

        //loanMap[msg.sender].deposited
        require(loanMap[msg.sender].depositedAvailable >= loanAmount, 'Not enough ETH deposited.');

        //Calls the calculateUsdc(uint loanAmount) function to calculate the loan amount and fee in USDC.
        //Pass the requested amount as the parameter..
        (uint amount, uint fee) = calculateUsdc(loanAmount);

        //Only allow withdraws if there is enough USDC to loan in the contract.
        require(usdc.balanceOf(address(this))>= amount, 'Not enough USDC in contract.');

        //Update the loan details associated with the user's address.
        loanMap[msg.sender].depositedAvailable -= loanAmount;
        loanMap[msg.sender].loan += amount;
        loanMap[msg.sender].fee += fee;

        //Transfer the calculated amount of USDC to the user's address.
        usdc.transfer(msg.sender, amount);
    }

    /*
    *   calculateUsdc(uint loanAmount) public view returns (uint, uint)
    *               param1  :   uint loanAmount        -   Amount of ether (in WEI, 18 decimals) that the user has deposited.
    *               returns :   uint amount            -   Amount to be withdrawn (USDC, 6 decimals).
    *                           uint fee               -   Amount of fee to be paid back (USDC, 6 decimals).
    *               bio     :   Function that calculates the available loan and fee based on the passed ether.
    *                           Converts the deposited ether (in WEI) to USDC.
    */
    function calculateUsdc(uint loanAmount) public view returns (uint, uint) {
        //Determine the loan amount by taking the percentage of the requested amount (in WEI, 18 decimals).
        uint amount = loanAmount * loanPercentage / 100;

        //Obtain the latest ETH/USDT price value from the SupraOracles S-Value Price Feed (feed returns 8 decimals).
        (int ethPrice, /*uint timestamp */) = sValueFeed.checkPrice("eth_usdt");
        //Cast the price value to uint and adjust to 18 points of conversion for calculation.
        uint eth = uint(ethPrice) * 10**10;

        //Convert WEI to USD
        amount = eth * amount;
        //Due to multiplication, amount is currently 10**36 (36 decimals). Convert to 6 to match USDC decimal count.
        amount = amount / (10 ** 30);

        //Calculate the fee on the USDC value.
        uint fee = amount * feePercentage / 100 ;

        //Return the loan amount and fee
        return (amount, fee);
    }

    /*
    *   payOff() external
    *               bio     :   Function that allows the user to pay off their loan. Users must pay off all at once.
    *                           Requires the user to have a loan balance that needs to be paid off.
    *                           Requires the user to have approved the proper amount of tokens to be transferred.
    *                           Updates loan details before handling token transfer and return of user's original ether deposit.
    *                           Transfers USDC from the user's wallet to this contract equivalent to the loan amount and fee.
    *                           Transfers the user's ether collateral from the contract to the user's wallet.
    */
    function payOff() external {
        //Only allow users with a loan to call this function.
        require(loanMap[msg.sender].loan > 0, 'No loan to pay off.');
        //Grab the required payment amount (loaned amount + fee)
        uint paymentAmount = loanMap[msg.sender].loan + loanMap[msg.sender].fee;
        //Only allow pay off if the user has set the proper allowance.
        require(usdc.allowance(msg.sender, address(this)) >= paymentAmount, 'Not enough allowance.');

        //Grab the amount of ether used for the loan.
        uint depositedAmount = loanMap[msg.sender].deposited - loanMap[msg.sender].depositedAvailable;

        //Update the loan details.
        loanMap[msg.sender].deposited = loanMap[msg.sender].depositedAvailable;
        loanMap[msg.sender].loan = 0;
        loanMap[msg.sender].fee = 0;

        //Transfer the USDC from the user's wallet to this contract.
        usdc.transferFrom(msg.sender, address(this), paymentAmount);
        //Transfer the originally deposited ether from this contract to the user's wallet.
        payable(msg.sender).transfer(depositedAmount);
    }


    /*
    *   withdrawEther() external
    *               bio     :   Function that allows the user to withdraw their deposited ether if they don't want a loan.
    *                           Requires the user to have enough available ether.
    *                           Requires the contract to have enough ether to return to the user.
    *                           Updates loan details before handling the return of user's original ether deposit.
    *                           Transfers the user's original ether deposit from the contract to the user's wallet.   
    */
    function withdrawEther(uint withdrawAmount) external {
        //Only allow user's to withdraw if they have enough ether available to be withdrawn.
        require(loanMap[msg.sender].depositedAvailable >= withdrawAmount, 'Not enough ether available to withdraw.');

        //Only allow the withdraw of ether if the contract has enough.
        require(address(this).balance >= withdrawAmount, 'Not enough ether in contract.');

        //Update the loan details.
        loanMap[msg.sender].deposited -= withdrawAmount; 
        loanMap[msg.sender].depositedAvailable -= withdrawAmount;

        //Transfer the originally deposited ether from this contract to the user's wallet.
        payable(msg.sender).transfer(withdrawAmount);
    }

    /*
    *   getLoanDetails() public view returns (bool, uint, uint, uint)
    *               returns :   uint deposited          -   Total Amount of ether that the user has deposited (WEI, 18 decimals).
    *                           uint depositedAvailable -   Amount of ether that the user has not used yet (WEI, 18 decimals).
    *                           uint loan               -   Amount of USDC that the user has withdrawn for their loan (USDC, 6 decimals).
    *                           uint fee                -   Amount of fee that the user must pay in addition to the original loan amount (USDC 6 decimals).
    *               bio     :   Function that returns the loan details for the calling user's address.
    */
    function getLoanDetails() public view returns (uint, uint, uint, uint){
        return (loanMap[msg.sender].deposited, loanMap[msg.sender].depositedAvailable, loanMap[msg.sender].loan, loanMap[msg.sender].fee);
    }

}