// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "../lib/forge-std/src/Script.sol";

import {console} from "../lib/forge-std/src/console.sol";
import {AbstractedAccount} from "../src/AbstractedAccount.sol";
import {AccountFactory} from "../src/AccountFactory.sol";
import {Paymaster} from "../src/Paymaster.sol";
import {SetupHelper} from "./SetupHelper.s.sol";

contract PaymasterDeployer is Script {
    function run() public {}

    function deployPaymaster(SetupHelper.NetworkConfig memory networkConfig) public returns (Paymaster) {
        vm.startBroadcast(networkConfig.wallet);
        Paymaster paymaster = new Paymaster(networkConfig.paymasterSignerWallet, networkConfig.entryPoint);
        vm.stopBroadcast();

        return paymaster;
    }
}
