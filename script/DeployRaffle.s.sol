//SPDX-Licence-Identifier: MIT
pragma solidity ^0.8.19;
import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script, CodeConstants {
    function run() public {}

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        if (config.subscriptionId == 0) {
            //Create subscription ID for Chainlink VRF
            CreateSubscription createSubscription = new CreateSubscription();
            config.subscriptionId = createSubscription.createSubscription(
                config.vrfCoordinator
            );
            //Fund subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinator,
                config.link,
                config.subscriptionId,
                FUND_AMOUNT
            );
        }
        console.log(
            "Deploying Raffle contract to the %s network",
            block.chainid
        );
        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.updateInterval,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit,
            config.vrfCoordinator
        );
        vm.stopBroadcast();
        //Add consumer
        if (block.chainid == LOCAL_CHAIN_ID) {
            AddConsumer addConsumer = new AddConsumer();
            addConsumer.addConsumer(
                address(raffle),
                config.vrfCoordinator,
                config.subscriptionId
            );
        }
        return (raffle, helperConfig);
    }
}
