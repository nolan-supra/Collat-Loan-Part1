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
    //Percentage used to calculate interest.
    uint public interestPercentage;
    //Minimum amount of ether to be deposited.
    uint public minimumDeposit;

    //Mapping of users address to loanDetails struct. Holds loan data for each user.
    mapping(address => loanDetails) public loanMap;

    //Struct for loan details
    struct loanDetails {
        bool loaned;    //Boolean flag to show loan status. FALSE = Not Taken, TRUE = Taken
        uint deposited; //Amount of ether (WEI) that the user has deposited for their loan.
        uint loan;      //Amount of USDC that the user has withdrawn for their loan.
        uint interest;  //Amount of interest that the user must pay in addition to the original loan amount.
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
        //Set the interest percenage to 10%.
        interestPercentage = 10;
        //Set the minimum deposit allowed to .1 ether.
        minimumDeposit = .1 ether;
    }

    /*
    *   depositEther() extrenal payable
    *               bio     :   Payable function that allows a user to deposit ether to the contract.
    *                           Requires the user to not have an active loan 
    *                           Requires the sent ether to be >= the set minimum deposit value.
    *                           User can make multiple deposits before taking a loan out.
    */
    function depositEther() external payable{
        //Only allow deposits for users that do not have an active loan. 
        //A loan is considered active (TRUE) once it is taken through the withdraw function.
        require(loanMap[msg.sender].loaned == false, 'User has an active loan.');

        //Only allow deposits that are >= the set minimumDeposit amount.
        require(msg.value >= minimumDeposit, 'Not enough ether sent.');

        //Update the amount of ether that the user has deposited.
        //By += the deposited amount, we enable the user to make multiple deposits before taking out a loan.
        loanMap[msg.sender].deposited += msg.value;
    } 


    /*
    *   withdrawUsdc() external
    *               bio     :   Function that allows the user to withdraw USDC (take the loan) dependent on their deposited amount.
    *                           Requires the user to not have an active loan.
    *                           Requires the user to have deposited ether >= the set minimum deposit value.
    *                           Requires the contract to have an enough USDC to loan.
    *                           Updates the loan details associated with the user's address
    *                           Transfers the USDC loan to the user's address.
    */
    function withdrawUsdc() external {
        //Only allow withdraws for users that do not have an active loan.
        require(loanMap[msg.sender].loaned == false, 'User has an active loan.');
        //Only allow withdraws for users that have deposited enough ether.
        require(loanMap[msg.sender].deposited >= minimumDeposit, 'Not enough ether deposited.');

        //Calls the calculateUsdc(uint depositedAmount) function to calculate the loan amount and interest in USDC.
        //Pass the user's amount of ether deposited as the depositedAmount parameter.
        (uint amount, uint interest) = calculateUsdc(loanMap[msg.sender].deposited);

        //Only allow withdraws if there is enough USDC to loan in the contract.
        require(usdc.balanceOf(address(this))>= amount, 'Not enough USDC in contract.');

        //Update the loan details associated with the user's address.
        loanMap[msg.sender].loan = amount;
        loanMap[msg.sender].interest = interest;
        loanMap[msg.sender].loaned = true;

        //Transfer the calculated amount of USDC to the user's address.
        usdc.transfer(msg.sender, amount);
    }

    /*
    *   calculateUsdc(uint depositedAmount) public view returns (uint, uint)
    *               param1  :   uint depositedAmount   -   Amount of ether (in WEI, 18 decimals) that the user has deposited.
    *               returns :   uint amount            -   Amount to be withdrawn (USDC, 6 decimals).
    *                           uint interest          -   Amount of interest to be paid back (USDC, 6 decimals).
    *               bio     :   Function that calculates the available loan and interest based on the user's deposited ether.
    *                           Converts the deposited ether (in WEI) to USDC.
    */
    function calculateUsdc(uint depositedAmount) public view returns (uint, uint) {
        //Determine the loan amount by taking the percentage of the user's deposited ether (in WEI, 18 decimals).
        uint amount = depositedAmount * loanPercentage / 100;

        //Obtain the latest ETH/USDT price value from the SupraOracles S-Value Price Feed (feed returns 8 decimals).
        (int ethPrice,) = sValueFeed.checkPrice("eth_usdt");
        //Cast the price value to uint and adjust to 18 points of conversion for calculation.
        uint eth = uint(ethPrice) * 10**10;

        //Convert WEI to USD
        amount = eth * amount;
        //Due to multiplication, amount is currently 10**36 (36 decimals). Convert to 6 to match USDC decimal count.
        amount = amount / (10 ** 30);

        //Calculate the interest on the USDC value.
        uint interest = amount * interestPercentage / 100 ;

        //Return the loan amount and interest
        return (amount, interest);
    }

    /*
    *   payOff() external
    *               bio     :   Function that allows the user to pay off their loan.
    *                           Requires the user to have an active loan.
    *                           Requires the user to have approved the proper amount of tokens to be transferred.
    *                           Updates loan details before handling token transfer and return of user's original ether deposit.
    *                           Transfers USDC from the user's wallet to this contract equivalent to the loan amount and interest.
    *                           Transfers the user's original ether deposit from the contract to the user's wallet.
    */
    function payOff() external {
        //Only allow pay off of users with an active loan.
        require(loanMap[msg.sender].loaned == true, 'No loan to pay off.');
        //Grab the required payment amount (loaned amount + interest)
        uint paymentAmount = loanMap[msg.sender].loan + loanMap[msg.sender].interest;
        //Only allow pay off if the user has set the proper allowance.
        require(usdc.allowance(msg.sender, address(this)) >= paymentAmount, 'Not enough allowance.');

        //Grab the original deposited amount.
        uint depositedAmount = loanMap[msg.sender].deposited;

        //Update the loan details.
        loanMap[msg.sender].loaned = false;
        loanMap[msg.sender].deposited = 0;
        loanMap[msg.sender].loan = 0;
        loanMap[msg.sender].interest = 0;

        //Transfer the USDC from the user's wallet to this contract.
        usdc.transferFrom(msg.sender, address(this), paymentAmount);
        //Transfer the originally deposited ether from this contract to the user's wallet.
        payable(msg.sender).transfer(depositedAmount);
    }


    /*
    *   withdrawEther() external
    *               bio     :   Function that allows the user to withdraw their deposited ether if they don't want a loan.
    *                           Requires the user to not have an active loan.
    *                           Requires the contract to have enough ether to return to the user.
    *                           Updates loan details before handling the return of user's original ether deposit.
    *                           Transfers the user's original ether deposit from the contract to the user's wallet.   
    */
    function withdrawEther() external {
        //Only allow user's to withdraw their deposited ether if they don't have an active loan.
        require(loanMap[msg.sender].loaned == false, 'User has an active loan.');

        //Grab the original deposited amount.
        uint depositedAmount = loanMap[msg.sender].deposited;
        
        require(depositedAmount > 0, 'No ether to withdraw.');

        //Only allow the withdraw of ether if the contract has enough.
        require(address(this).balance >= depositedAmount, 'Not enough ether in contract.');

        //Update the loan details.
        loanMap[msg.sender].loaned = false;
        loanMap[msg.sender].deposited = 0;
        loanMap[msg.sender].loan = 0;
        loanMap[msg.sender].interest = 0;

        //Transfer the originally deposited ether from this contract to the user's wallet.
        payable(msg.sender).transfer(depositedAmount);
    }

    /*
    *   getLoanDetails() public view returns (bool, uint, uint, uint)
    *               returns :   bool loaned            -   Loan status. FALSE = Not taken, TRUE = Taken
    *                           uint deposited         -   Amount of ether that the user has deposited for their loan (WEI, 18 decimals).
    *                           uint loan              -   Amount of USDC that the user has withdrawn for their loan (USDC, 6 decimals).
    *                           uint interest          -   Amount of interest that the user must pay in addition to the original loan amount (USDC 6 decimals).
    *               bio     :   Function that returns the loan details for the calling user's address.
    */
    function getLoanDetails() public view returns (bool, uint, uint, uint){
        return (loanMap[msg.sender].loaned, loanMap[msg.sender].deposited, loanMap[msg.sender].loan, loanMap[msg.sender].interest);
    }

}