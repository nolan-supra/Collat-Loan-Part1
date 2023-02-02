

# Build:

    forge build

# Testing:

    forge test --fork-url <GOERLI ETH RPC URL> -vv
    forge test --fork-url <GOERLI ETH RPC URL> -vvvv

Adding the following allows you to only execute matching tests:

    --match-test testDeposit
    --match-test testWithdrawUsdc
    --match-test testCalculateUsdc
    --match-test testPayOff
    --match-test testWithdrawEther

Example:

    forge test --fork-url <GOERLI ETH RPC URL> -vv --match-test testDeposit