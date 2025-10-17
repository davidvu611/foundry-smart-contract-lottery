//SPDX-Licesnce-Identifier: MIT
pragma solidity ^0.8.19;
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test, CodeConstants {
    event RaffleEnter(address indexed player);
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    HelperConfig.NetworkConfig config;
    Raffle raffle;
    address public PLAYER1 = makeAddr("player1");

    modifier raffleEnter() {
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: config.entranceFee}();
        vm.warp(block.timestamp + config.updateInterval);
        vm.roll(block.number + 1);
        _;
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (Raffle _raffle, HelperConfig helperConfig) = deployer.deployContract();
        raffle = _raffle;
        config = helperConfig.getConfig();
        vm.deal(PLAYER1, STARTING_USER_BALANCE);
    }

    //===========================================
    //          Enter Raffle
    //===========================================
    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertWhenNotPayEnough() public {
        // Arrange
        vm.prank(PLAYER1);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle{value: 0.001 ether}();
    }

    function testRaffleRecordPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER1);
        // Act
        raffle.enterRaffle{value: config.entranceFee}();
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
        raffle.enterRaffle{value: config.entranceFee}();
    }

    function testDontAllowEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: config.entranceFee}();
        vm.warp(block.timestamp + config.updateInterval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        // Act/Assert
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: config.entranceFee}();
    }

    //===========================================
    //          Check upkeep
    //===========================================
    function testCheckUpkeepReturnsFalseIfItHasNoBaance() public {
        // Arrange
        vm.warp(block.timestamp + config.updateInterval + 1);
        vm.roll(block.number + 1);
        (bool upkeepHeld, ) = raffle.checkUpkeep("");
        // Act/Assert
        assertEq(upkeepHeld, false);
    }

    function testCheckUpkeepReturnsFalseIfItNotOpen() public {
        // Arrange
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: config.entranceFee}();
        vm.warp(block.timestamp + config.updateInterval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        // Act
        (bool upkeepHeld, ) = raffle.checkUpkeep("");
        //Assert
        assertEq(upkeepHeld, false);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: config.entranceFee}();

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenAllParametersGood()
        public
        raffleEnter
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
        raffleEnter
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
        raffle.enterRaffle{value: config.entranceFee}();
        currentBalance = config.entranceFee;
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

    function testPerformUpkeepUpdateRaffleStateAndEmitRquestId()
        public
        raffleEnter
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
}
