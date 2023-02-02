

# Build:

    forge build

# Testing:

    forge test --fork-url https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161 -vv
    forge test --fork-url https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161 -vvvv

GOERLI ETH RPC URL for fork pulled from: https://rpc.info/

Adding the following allows you to only execute matching tests:

    --match-test testDeposit
    --match-test testWithdrawUsdc
    --match-test testCalculateUsdc
    --match-test testPayOff
    --match-test testWithdrawEther

Example:

    forge test --fork-url <GOERLI ETH RPC URL> -vv --match-test testDeposit