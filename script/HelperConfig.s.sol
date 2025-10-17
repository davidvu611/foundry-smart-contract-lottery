// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

/* Errors */
error HelperConfig__ConfigChainIdError();

abstract contract CodeConstants {
    /* CHAIN IDS */
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    // uint256 public constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint constant MAIN_ETH_CHAINID = 1;

    /* MOCK VRF values*/
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 public constant MOCK_WEI_PER_UINT_LINK = 4e15;

    uint96 public constant ENTRANCE_FEE = 0.01 ether;
    uint96 public constant FUND_AMOUNT = 1 ether; // 1 LINK
}

contract HelperConfig is CodeConstants, Script {
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 updateInterval;
        address vrfCoordinator;
        bytes32 gasLane; //Gas price
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }

    constructor() {
        activeNetworkConfig = getConfigByChainId(block.chainid);
    }

    // https://docs.chain.link/data-feeds/price-feeds/addresses
    // Sepolia ETH / USD Address: 0x694AA1769357215DE4FAC081bf1f309aDC325306
    // Main ETH / USD Address: 0x1a81afB8146aeFfCFc5E50e8479e826E7D55b910
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: ENTRANCE_FEE,
                updateInterval: 30, // 30 secs
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // 500 gwei Key Hash
                callbackGasLimit: 500000,
                subscriptionId: 25450339630469797517993455814994251089370318040188202137417761622385966266122,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            });
    }

    function getMainEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: ENTRANCE_FEE,
                updateInterval: 30, // 30 secs
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, // FIX LATER
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // 500 gwei Key Hash
                callbackGasLimit: 500000,
                subscriptionId: 0,
                link: 0x514910771AF9Ca656af840dff83E8264EcF986CA
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        // Deploy Mock VRF Feed
        VRFCoordinatorV2_5Mock vrfCoordinator = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UINT_LINK
        );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();
        console.log(
            "VRFCoordinatorV2_5Mock deployed at %s",
            address(vrfCoordinator)
        );
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
                link: address(linkToken)
            });
    }

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID) {
            return getSepoliaEthConfig();
        }
        if (chainId == MAIN_ETH_CHAINID) {
            return getMainEthConfig();
        }
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        }
        revert HelperConfig__ConfigChainIdError();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }
}
