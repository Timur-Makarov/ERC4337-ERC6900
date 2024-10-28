// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {EntryPoint} from "../lib/account-abstraction/contracts/core/EntryPoint.sol";
import {Script} from "../lib/forge-std/src/Script.sol";

contract SetupHelper is Script {
    struct NetworkConfig {
        address entryPoint;
        address wallet;
        address paymasterSignerWallet;
    }

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ANVIL_CHAIN_ID = 31337;
    address public constant TESTNET_WALLET = 0x9b60f904052Dc42557b20e169320715A320bB74C;
    address public constant ANVIL_WALLET = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 public constant ANVIL_WALLET_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    address public immutable PAYMASTER_SIGNER_WALLET = makeAddr("paymaster");

    NetworkConfig public localNetworkConfig;

    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
    }

    function getNetworkConfig() public returns (NetworkConfig memory) {
        return getNetworkConfigByChainId(block.chainid);
    }

    function getNetworkConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == ANVIL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else if (networkConfigs[chainId].wallet != address(0)) {
            return networkConfigs[chainId];
        } else {
            revert("Config with provided chain id is not implemented");
        }
    }

    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789,
            wallet: TESTNET_WALLET,
            paymasterSignerWallet: TESTNET_WALLET
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.wallet != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast(ANVIL_WALLET);
        EntryPoint entryPoint = new EntryPoint();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entryPoint: address(entryPoint),
            wallet: ANVIL_WALLET,
            paymasterSignerWallet: PAYMASTER_SIGNER_WALLET
        });

        return localNetworkConfig;
    }
}
