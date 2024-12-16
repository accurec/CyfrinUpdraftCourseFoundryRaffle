-include .env

.PHONY: all test deploy deploy-sepolia

build:
	forge build

test:
	forge test

install:
	forge install cyfrin/foundry-devops@0.2.2 --no-commit
	forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit
	forge install foundry-rs/forge-std@v1.8.2 --no-commit
	forge install transmissions11/solmate@v6 --no-commit

deploy-local:
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(LOCAL_RPC_URL) --account defaultKey --broadcast -vvvv

get-local-entrance-fee:
	@cast call $(LOCAL_RAFFLE_ADDRESS) "getEntranceFee()" --rpc-url $(LOCAL_RPC_URL)

local-check-balance:
	@cast balance $(LOCAL_RAFFLE_ADDRESS) --rpc-url $(LOCAL_RPC_URL)

get-local-recent-winner:
	@cast call $(LOCAL_RAFFLE_ADDRESS) "getRecentWinner()" --rpc-url $(LOCAL_RPC_URL)

get-local-raffle-state:
	@cast call $(LOCAL_RAFFLE_ADDRESS) "getRaffleState()" --rpc-url $(LOCAL_RPC_URL)

local-check-upkeep:
	@cast call $(LOCAL_RAFFLE_ADDRESS) "checkUpkeep(bytes)" 0x --rpc-url $(LOCAL_RPC_URL)

local-get-first-player:
	@cast call $(LOCAL_RAFFLE_ADDRESS) "getPlayer(uint256)" 0 --rpc-url $(LOCAL_RPC_URL)

local-enter-raffle:
	@cast send $(LOCAL_RAFFLE_ADDRESS) "enterRaffle()" --value $(LOCAL_SEND_VALUE) --rpc-url $(LOCAL_RPC_URL) --account defaultKey

local-perform-upkeep:
	@cast send $(LOCAL_RAFFLE_ADDRESS) "performUpkeep(bytes)" 0x --rpc-url $(LOCAL_RPC_URL) --account defaultKey -vvvvv

local-vrf-coordinator-fulfill-random-words:
	@cast send $(LOCAL_VRF_COORDINATOR) "fulfillRandomWords(uint256, address)" 1 $(LOCAL_RAFFLE_ADDRESS) --rpc-url $(LOCAL_RPC_URL) --account defaultKey

deploy-sepolia:
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) --account sepoliaKey --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv