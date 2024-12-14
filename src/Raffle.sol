// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/v0.8/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title A sample raffle contract
 * @author Zhernovkov Maxim
 * @notice This contract is for reating a sample raffle
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);
    error Raffle__TransferFailed();
    error Raffle__RaffleIsNotOpen();

    /**
     * Type declarations
     */
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1

    }

    /**
     * State variables
     */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint16 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    // @dev The duration of lottery round in seconds
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimestamp;
    address private s_mostRecentWinner;
    RaffleState private s_raffleState;

    /**
     * Events
     */
    event Raffle__Entered(address indexed player);
    event Raffle__WinnerPicked(address indexed winner);
    event Raffle__RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimestamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // Custom errors are more gas efficient than require.
        if (msg.value < i_entranceFee) revert Raffle__SendMoreToEnterRaffle();
        if (s_raffleState != RaffleState.OPEN) revert Raffle__RaffleIsNotOpen();

        address newPlayer = msg.sender;

        s_players.push(payable(newPlayer));

        // Rule of thumb - when we update storage we want to emit events.
        emit Raffle__Entered(newPlayer);
    }

    /**
     * @dev This is the function that Chainlink nodes will call to check if lottery is ready to have another round.
     * The following should be true in order for the upkeep to be true:
     * 1. The time interval has passed between raffle runs
     * 2. The raffle state is open
     * 3. The contract has ETH
     * 4. Implicitly your subscription has LINK
     * @param - ignored
     * @return upkeepNeeded - true, if it's time to restart the lottery
     * @return - ignored
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool timHasPassed = block.timestamp - s_lastTimestamp >= i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        upkeepNeeded = timHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */ ) external override {
        // Since this function can be called by either Chainlink or anyone, we need to run the check as to whether
        // The upkeep is needed - kind of redundant, but necessary.
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;

        // Get our random number using VRFv2.5
        // Using VRF is a two step process: request RNG and then get the actual RNG using callback
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });

        // This is technically redundant, because vrfCoordinator is emitting "RandomWordsRequested" event when
        // running "requestRandomWords". But done here to make writing tests easier for the sake of this lesson.
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit Raffle__RequestedRaffleWinner(requestId);
    }

    // When we request Chainlink to perform "VRFV2PlusClient.RandomWordsRequest", then chainlink will respond to us
    // by calling "rawFulfillRandomWords" function, which will then call this function. So we need to implement our
    // callback handler and how we use generated random number. Since we inherit from the "VRFConsumerBaseV2Plus", this
    // internal function will be accessible.
    // CEI: Checks, Effects, Interactions pattern - good practice for Solidity smart contracts.
    function fulfillRandomWords(uint256, /* requestId */ uint256[] calldata randomWords) internal override {
        // Checks (requires, conditionals, etc.)

        // Effects (internal contract state)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable mostRecentWinner = s_players[indexOfWinner];

        s_mostRecentWinner = mostRecentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;

        emit Raffle__WinnerPicked(s_mostRecentWinner);

        // Interactions (external contract interactions)
        (bool success,) = mostRecentWinner.call{value: address(this).balance}("");
        if (!success) revert Raffle__TransferFailed();
    }

    /**
     * Getter functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getLastTimestamp() external view returns (uint256) {
        return s_lastTimestamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_mostRecentWinner;
    }
}
