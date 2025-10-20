//SPDX-Licesnce-Identifier: MIT
pragma solidity ^0.8.19;
import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";
import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test, CodeConstants {
    event RaffleEnter(address indexed player);
    uint256 public constant STARTING_USER_BALANCE = 1 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    HelperConfig.NetworkConfig networkConfig;
    Raffle raffle;
    address public PLAYER1 = makeAddr("player1");

    modifier raffleEntered() {
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: networkConfig.entranceFee}();
        vm.warp(block.timestamp + networkConfig.updateInterval);
        vm.roll(block.number + 1);
        _;
    }

    modifier onlyLocalChain() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        HelperConfig helperConfig;
        (raffle, helperConfig) = deployer.deployContract();
        networkConfig = helperConfig.getConfig();
        vm.deal(PLAYER1, STARTING_USER_BALANCE);
        LinkToken link = LinkToken(networkConfig.link);

        vm.startPrank(msg.sender);
        if (block.chainid == LOCAL_CHAIN_ID) {
            link.mint(msg.sender, LINK_BALANCE);
            VRFCoordinatorV2_5Mock(networkConfig.vrfCoordinator)
                .fundSubscription(networkConfig.subscriptionId, LINK_BALANCE);
        }
        link.approve(networkConfig.vrfCoordinator, LINK_BALANCE);
        vm.stopPrank();
    }

    //===========================================
    //          Enter Raffle
    //===========================================
    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER1);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle{value: 0.000001 ether}();
    }

    function testRaffleRecordPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER1);
        // Act
        raffle.enterRaffle{value: networkConfig.entranceFee}();
        // Assert
        assertEq(raffle.getPlayer(0), PLAYER1);
    }

    function testEnterRaffleEmitsEvent() public {
        // Arrange
        vm.prank(PLAYER1);
        // Act
        vm.expectEmit(true, true, true, true, address(raffle));
        emit RaffleEnter(PLAYER1);
        // Assert
        raffle.enterRaffle{value: networkConfig.entranceFee}();
    }

    function testDontAllowEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: networkConfig.entranceFee}();
        vm.warp(block.timestamp + networkConfig.updateInterval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        // Act/Assert
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: networkConfig.entranceFee}();
    }

    //===========================================
    //          Check upkeep
    //===========================================
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + networkConfig.updateInterval + 1);
        vm.roll(block.number + 1);
        (bool upkeepHeld, ) = raffle.checkUpkeep("");
        // Act/Assert
        assertEq(upkeepHeld, false);
    }

    function testCheckUpkeepReturnsFalseIfItNotOpen() public {
        // Arrange
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: networkConfig.entranceFee}();
        vm.warp(block.timestamp + networkConfig.updateInterval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // Act
        (bool upkeepHeld, ) = raffle.checkUpkeep("");
        //Assert
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        assertEq(upkeepHeld, false);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: networkConfig.entranceFee}();

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenAllParametersGood()
        public
        raffleEntered
    {
        // Arrange

        // Act
        (bool upkeepHeld, ) = raffle.checkUpkeep("");
        //Assert
        assertEq(upkeepHeld, true);
    }

    //===========================================
    //          Perform upkeep
    //===========================================
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue()
        public
        raffleEntered
    {
        // Arrange

        // Act / Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: networkConfig.entranceFee}();
        currentBalance = networkConfig.entranceFee;
        numPlayers = 1;
        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdateRaffleStateAndEmitRequestId()
        public
        raffleEntered
    {
        // Arrange

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        // Assert
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
        assert(uint(requestId) > 0);
    }

    //===========================================
    //          Fullfill randomwords
    //===========================================

    function testFullfillRandomwordsCanOnlyBeCallAfterPerformUpkeep(
        uint256 requestId
    ) public raffleEntered {
        // Act/Assert
        //vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        vm.expectRevert();
        VRFCoordinatorV2_5Mock(networkConfig.vrfCoordinator).fulfillRandomWords(
                requestId,
                address(raffle)
            );
    }

    function testFullfillRandomwordsPickAWinnerResetAndSendMoney()
        public
        raffleEntered
        onlyLocalChain
    {
        // Why do we know this is the winner?
        // the vrf mock will always return 1 as the random number?
        address expectedWinner = address(1);
        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            //address player = makeAddr(string.concat("player", vm.toString(i)));
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: networkConfig.entranceFee}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console2.logBytes32(entries[1].topics[1]);
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2_5Mock(networkConfig.vrfCoordinator).fulfillRandomWords(
                uint256(requestId),
                address(raffle)
            );

        //Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimestamp = raffle.getLastTimeStamp();
        uint256 prize = networkConfig.entranceFee * (additionalEntrants + 1);

        console2.log("recentWinner", recentWinner);
        assertEq(recentWinner, expectedWinner);
        assertEq(winnerBalance, winnerStartingBalance + prize);
        assert(raffleState == Raffle.RaffleState.OPEN);
        assert(endingTimestamp > startingTimeStamp);
    }
}
