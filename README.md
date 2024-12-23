## About

As part of my learning path of smart contract/blockchain/web3 development I took [Cyfrin Updraft](https://updraft.cyfrin.io/dashboard) course. This repository is a result of me learning [Foundry fundamentals](https://updraft.cyfrin.io/courses/foundry) lesson. Thank you Patrick and the team for putting together such an amazing learning resource!

The core of the application is a `Raffle` smart contract. The idea of this application is to have an automatic on-chain raffle application that allows users to enter raffle by sending funds to the application. Then after enough time has passed the raffle is supposed to figure figure out who is going to be the winner among users who enetered the raffle since last round was finished. 

In this application I needed to generate random numbers to choose the winners, as well as be able to run the raffle automatically on schedule. To achieve this I've made use of Chainlink's [VRF](https://docs.chain.link/vrf) capability and [Automation service](https://docs.chain.link/chainlink-automation).

![Raffle Architecture Diagram](/resources/Raffle%20diagram.png)

## Learnings and techniques used

As part of lesson I've learned a bunch of things:

1) Chainlink VRF service to generate random numbers on-chain.
2) Chainlink Automation service to be able to trigger smart contract function calls on schedule.
3) Better naming conventions for variable names, events, errors. Better organization of smart conract variables and functions within the file.
4) Using enums.
5) Emitting and reading from events data. Indexing.
6) Reverting errors with parameters.
7) Uisng inherited constructors with parameters in the child smart contracts (`VRFConsumerBaseV2Plus`).
8) Using mocks to work with ERC20 token (deploying `LINK` token locally).
9) Using `abstract contract` to make contracts more modular.
10) Using `vm.startBroadcast()` with different accounts.
11) Using Chainlink brownie contracts mocks for VRF coordinator.
12) Learned `vm.warp()` and `vm.roll()`.
13) Setting `vm.expectRevert()` with specific error codes and parameters passed to the error.
14) Setting expectations for specific events using `vm.expectEmit()`.
15) Learned how to use `vm.recordLogs()` to read from logs data.

## How to use this repository

1) Run 
```
git clone https://github.com/accurec/CyfrinUpdraftCourseFoundryRaffle.git
```
2) Run `make install` to install required dependencies.
3) Run `make build` to build the project.
4) Add `.env` file with the following variables: `SEPOLIA_RPC_URL` - could take this from Alchemy; `ETHERSCAN_API_KEY` - needed for automatic verification, can get it from Etherscan account.
5) Make sure that in `HelperConfig.s.sol` the following values are properly setup for your subscription and account in `getSepoliaEthConfig` function: `subscriptionId` and `account`.
6) Make sure you have encrypted and saved your Sepolia private key using `cast wallet import --interactive sepoliaKey` for the account that you have setup in the previous step in `HelperConfig.s.sol` file.
7) Make sure you have some testnet ETH and LINK balance on the account that you have specified in step #5 above. These are good faucets to use to get some: [ETH Sepolia faucet](https://cloud.google.com/application/web3/faucet/ethereum/sepolia) and [LINK and ETH Sepolia faucet](https://faucets.chain.link/sepolia).
8) Make sure you've created subscription for VRF using [this link](https://vrf.chain.link/) and funded it with enough LINK. Use the subscription ID that you get from it and replace in `HelperConfig.s.sol` file for `getSepoliaEthConfig()` function, `subscriptionId` field.
9) You can now deploy to Sepolia using `make deploy-sepolia` command.
10) Alternatively, can deploy locally and run `make deploy-local`. Make sure to encrypt Anvil's key for the address `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` using `cast wallet import` command. After deployment we can wait for `30 seconds` (interval time) and then run `make local-enter-raffle`. Then we can run `make local-perform-upkeep` and then `local-vrf-coordinator-fulfill-random-words` to simulate Chainlink's Automation and VRF request fulfillments. After that we can observe that the winner of the raffle has been set by running `make get-local-recent-winner`. 

**NOTE 1:** A little hacky way, but I have not been able to figure out quicker way for now to fix the problem with 0 blocks blockchain when running `anvil` is to go directly to `lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/SubscriptionAPI.sol` and modify the line where the subscription ID is set based on the `block - 1` logic by removing the `-1` part before running `make deploy-local`: 
```
keccak256(abi.encodePacked(msg.sender, blockhash(block.number - 1), address(this), currentSubNonce))
```

**NOTE 2:** For `.env` file the local values reference is:
```
LOCAL_RPC_URL=http://127.0.0.1:8545
LOCAL_RAFFLE_ADDRESS=0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9
LOCAL_VRF_COORDINATOR=0x5FbDB2315678afecb367f032d93F642f64180aa3
LOCAL_SEND_VALUE=50000000000000000 # 0.05 ETH
```

## End-to-end walkthrough on Sepolia test network

1) After deploying to Sepolia we can look at the contract state variables. [Example](https://sepolia.etherscan.io/address/0x7b9c63f3B6A5Be805234F23d5689AFeACb476602#readContract). We can see latest winner and verify that if raffle has never been run then the address will be a zero address.
2) We then can register a new upkeep in Chainlink. [Example](https://automation.chain.link/sepolia/56794300597436026353414141436479458441442761384838899883395464310339413823361).
3) Once the upkeep has been registered, we can go ahead and write to our `Raffle` contract to `enterRaffle` function with any value that is higher than the minimum entry fee.
4) Once this is done, we can wait an amount of time that has been configured in `HelperConfig.s.sol` file `getSepoliaEthConfig()` function `interval` parameter, and see that Chainlink called `performUpkeep()` function.
5) Once the `performUpkeep()` is called then the control flow is passed to VRF, which will call `fulfillRandomWords` function on the contract once the random values are ready. [Example](https://sepolia.etherscan.io/tx/0x0f7d4f9d1a5d3fe56858170f9989b117fe2897aa370ebeca575ae9d12ba1b37e) can see internal call to `Fulfill Random Words`.
6) We then can check that the latest winner has been updated in our contract by reading from it and verify that the winner was indeed us.

## Useful resources

1) [Chainlink VRF](https://docs.chain.link/vrf)
2) [Chainlink Automation](https://docs.chain.link/chainlink-automation)
3) [LINK token contracts](https://docs.chain.link/resources/link-token-contracts)
4) [Signature Database](https://openchain.xyz/signatures)
5) [Foundry DevOps](https://github.com/Cyfrin/foundry-devops)

## Things to improve

1) Write integration tests.
2) Add interaction for registering an upkeep for `Raffle` contract.