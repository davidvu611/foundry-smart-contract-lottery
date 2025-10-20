// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {LinkToken} from "../test/mocks/LinkToken.sol";
import {Script, console2} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

abstract contract CodeConstants {
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 public constant MOCK_WEI_PER_UINT_LINK = 4e15;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    uint96 public constant ENTRANCE_FEE = 0.01 ether;
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfig__InvalidChainId();

    mapping(uint256 chainId => NetworkConfig) public networkConfigs;
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 updateInterval;
        address vrfCoordinator;
        bytes32 gasLane; //Gas price
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        address account;
    }

    constructor() {
        networkConfigs[LOCAL_CHAIN_ID] = getOrCreateAnvilEthConfig();
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
        networkConfigs[ETH_MAINNET_CHAIN_ID] = getMainnetEthConfig();
    }

    function getConfig() public view returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function setConfig(
        uint256 chainId,
        NetworkConfig memory networkConfig
    ) public {
        networkConfigs[chainId] = networkConfig;
    }

    function getConfigByChainId(
        uint256 chainId
    ) public view returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        }
        revert HelperConfig__InvalidChainId();
    }

    function getMainnetEthConfig()
        public
        pure
        returns (NetworkConfig memory mainnetNetworkConfig)
    {
        mainnetNetworkConfig = NetworkConfig({
            subscriptionId: 0, // If left as 0, our scripts will create one!
            gasLane: 0x9fe0eebf5e446e3c998ec9bb19951541aee00bb90ea201ae456421a2ded86805,
            updateInterval: 30, // 30 seconds
            entranceFee: 0.01 ether,
            callbackGasLimit: 500000, // 500,000 gas
            vrfCoordinator: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
            link: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            account: 0x643315C9Be056cDEA171F4e7b2222a4ddaB9F88D
        });
    }

    function getSepoliaEthConfig()
        public
        pure
        returns (NetworkConfig memory sepoliaNetworkConfig)
    {
        sepoliaNetworkConfig = NetworkConfig({
            //subscriptionId: 0, // If left as 0, our scripts will create one!
            subscriptionId: 25450339630469797517993455814994251089370318040188202137417761622385966266122,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // 500 gwei Key Hash
            updateInterval: 30, // 30 seconds
            entranceFee: 0.01 ether,
            callbackGasLimit: 500000, // 500,000 gas
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0xD443e5082979773227d1e8Cf66Bf9BF45B405eCa
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        vm.startBroadcast();
        // Deploy Mock VRF Feed
        VRFCoordinatorV2_5Mock vrfCoordinator = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UINT_LINK
        );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();
        return
            NetworkConfig({
                entranceFee: ENTRANCE_FEE,
                updateInterval: 30, // 30 secs
                vrfCoordinator: address(vrfCoordinator),
                //Does not matter what we put here, as long as the gas lane exists in the coordinator
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // 500 gwei Key Hash
                callbackGasLimit: 500000,
                // Deploy script will create it
                subscriptionId: 0,
                link: address(linkToken),
                // Foundry default sender : see Base.sol
                account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
            });
    }
}
