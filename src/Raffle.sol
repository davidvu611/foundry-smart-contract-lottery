// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title a minimum Raffle contract
 * @author David Vu
 * @notice  This implements the basic features of a raffle contract
 * @dev : Ness Chainlink VRF and Chainlink Keepers
 */

contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__SendRaffleWinnerFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 balance,
        uint256 playerlength,
        RaffleState s_raffleState
    );

    /* Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* State varriables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    // The time (in seconds) interval for the raffle to pick a winner
    uint256 private immutable i_interval;
    bytes32 private immutable i_gasLane;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint256 private s_lastBlockTimestamp;
    RaffleState private s_raffleState;
    address payable[] private s_players;
    address payable recentWinner;

    /* Events */
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);
    event RequestRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        bytes32 gasLane, //Gas price
        uint256 subscriptionId,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastBlockTimestamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    /*
     * @dev This is the function that the Chainlink Automation nodes call
     * they look for `upkeepNeeded` to return true.
     * The following should be true in order to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The raffle is "open".
     * 3. The raffle has players or balance.
     * 4. Implicity, your subscription is funded with LINK.
     */

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool interalPassed = block.timestamp - s_lastBlockTimestamp >=
            i_interval;
        bool isOpen = (s_raffleState == RaffleState.OPEN);
        bool hasPlayers = s_players.length > 0;
        //bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (interalPassed && isOpen && hasPlayers);

        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        // Revalidating the upkeep for safety
        (bool upkeepNeeded, ) = this.checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                s_raffleState
            );
        }

        s_raffleState = RaffleState.CALCULATING;

        // Get a random number to determine the winner (index of the players array)
        //1. Request a random number
        //2. Get a random number
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] calldata randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        recentWinner = s_players[indexOfWinner];
        // Reset the raffle
        s_players = new address payable[](0);
        s_raffleState = RaffleState.OPEN;
        s_lastBlockTimestamp = block.timestamp;
        emit WinnerPicked(recentWinner);

        // Send the money to the winner: interact with external contract
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__SendRaffleWinnerFailed();
        }
    }

    /* getter funtion */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }
}
