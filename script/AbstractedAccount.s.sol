// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "../lib/forge-std/src/Script.sol";

import {AbstractedAccount} from "../src/AbstractedAccount.sol";
import {AccountFactory} from "../src/AccountFactory.sol";
import {SetupHelper} from "./SetupHelper.s.sol";

contract AccountsDeployer is Script {
    function run() public {}

    // Single account owned by TESTNET_WALLET
    function deployAccount(SetupHelper.NetworkConfig memory networkConfig) public returns (AbstractedAccount) {
        vm.startBroadcast(networkConfig.wallet);
        AbstractedAccount account = new AbstractedAccount(networkConfig.wallet, networkConfig.entryPoint);
        vm.stopBroadcast();

        return account;
    }

    // Account Factory that creates AbstractedAccount's
    function deployAccountFactory() public returns (AccountFactory) {
        vm.startBroadcast();
        AccountFactory factory = new AccountFactory();
        vm.stopBroadcast();

        return factory;
    }
}
