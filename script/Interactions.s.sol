//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

contract CreateSubscription is Script, CodeConstants {
    error HelperConfig__ConfigChainIdError();

    function run() public returns (uint256) {
        //Create subscription ID for Chainlink VRF
        return createSubscriptionUsingConfig();
    }

    function createSubscription(
        address vrfCoordinatorV2_5
    ) public returns (uint256) {
        console.log("Creating subscription on chain:", block.chainid);
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Subscription id is:", subId);
        return subId;
    }

    function createSubscriptionUsingConfig() public returns (uint256) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig
            .getConfigByChainId(block.chainid);
        if (block.chainid == LOCAL_CHAIN_ID) {
            uint256 subId = createSubscription(config.vrfCoordinator);
            return subId;
        }
        if (config.subscriptionId == 0) {
            revert HelperConfig__ConfigChainIdError();
        }
        return config.subscriptionId;
    }
}

contract FundSubscription is Script, CodeConstants {
    function run() public {
        fundSubscriptionUsingConfig();
    }

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig
            .getConfigByChainId(block.chainid);
        fundSubscription(
            config.vrfCoordinator,
            config.link,
            config.subscriptionId,
            FUND_AMOUNT
        );
    }

    function fundSubscription(
        address vrfCoordinatorV2_5,
        address linkToken,
        uint256 subId,
        uint96 amount
    ) public {
        console.log("Funding subscription:", subId);
        console.log("vrfCoordinator:", vrfCoordinatorV2_5);
        console.log("Chain:", block.chainid);
        console.log("Link token:", linkToken);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(
                subId,
                amount
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(
                vrfCoordinatorV2_5,
                amount,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
        console.log("Funded amount is:", amount);
    }
}

contract AddConsumer is Script, CodeConstants {
    function run() public {
        address contractAddToVrf = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(contractAddToVrf);
    }

    function addConsumerUsingConfig(address contractAddToVrf) public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig
            .getConfigByChainId(block.chainid);
        addConsumer(
            contractAddToVrf,
            config.vrfCoordinator,
            config.subscriptionId
        );
    }

    function addConsumer(
        address consumerContractAddr,
        address vrfCoordinator,
        uint256 subId
    ) public {
        console.log("Chain Id: ", block.chainid);
        console.log("Add cunsumer contract: ", consumerContractAddr);
        console.log("vrfCoordinator: ", vrfCoordinator);
        console.log("Subscription Id:", subId);
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subId,
            consumerContractAddr
        );
        vm.stopBroadcast();
        console.log("Consumer added");
    }
}
