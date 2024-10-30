// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {
    ExecutionManifest,
    ManifestExecutionFunction
} from "../lib/reference-implementation/src/interfaces/IExecutionModule.sol";
import {
    ExecutionManifest, IExecutionModule
} from "../lib/reference-implementation/src/interfaces/IExecutionModule.sol";
import {BaseModule} from "../lib/reference-implementation/src/modules/BaseModule.sol";
import {IModule} from "../lib/reference-implementation/src/interfaces/IModule.sol";
import {SingleSignerValidationModule} from
    "../lib/reference-implementation/src/modules/validation/SingleSignerValidationModule.sol";
import {IModularAccount} from "../lib/reference-implementation/src/interfaces/IModularAccount.sol";

contract SubscriptionModule is BaseModule, IExecutionModule {
    mapping(address => mapping(address => Subscription)) public subscriptions;

    struct Subscription {
        uint256 amount;
        uint256 lastPaymentTimestamp;
        bool enabled;
    }

    function subscribe(address service, uint256 amount) external {
        subscriptions[service][msg.sender] = Subscription({amount: amount, lastPaymentTimestamp: 0, enabled: true});
    }

    function paySubscription(address service, uint256 amount) external {
        Subscription storage sub = subscriptions[service][msg.sender];
        require(sub.amount <= amount, "The amount to pay cannot be less than agreed upon");
        require(block.timestamp - sub.lastPaymentTimestamp >= 4 weeks, "The last payment was earlier than 4 weeks ago");
        require(sub.enabled, "The subscription has to be active");

        sub.lastPaymentTimestamp = block.timestamp;
        IModularAccount(msg.sender).execute(service, amount, "");
    }

    function onInstall(bytes calldata) external pure override {}

    function onUninstall(bytes calldata) external pure override {}

    function executionManifest() external pure override returns (ExecutionManifest memory) {
        ExecutionManifest memory manifest;

        manifest.executionFunctions = new ManifestExecutionFunction[](2);
        manifest.executionFunctions[0] = ManifestExecutionFunction({
            executionSelector: this.subscribe.selector,
            skipRuntimeValidation: false,
            allowGlobalValidation: true
        });
        manifest.executionFunctions[1] = ManifestExecutionFunction({
            executionSelector: this.paySubscription.selector,
            skipRuntimeValidation: false,
            allowGlobalValidation: true
        });

        return manifest;
    }

    function moduleId() external pure returns (string memory) {
        return "tm.subscription-module.1.0.0";
    }
}
