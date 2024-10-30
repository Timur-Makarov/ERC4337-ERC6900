// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ReferenceModularAccount} from "../lib/reference-implementation/src/account/ReferenceModularAccount.sol";
import {SingleSignerFactoryFixture} from "../lib/reference-implementation/test/mocks/SingleSignerFactoryFixture.sol";
import {ExecutionManifest} from "../lib/reference-implementation/src/interfaces/IExecutionModule.sol";
import {ModuleEntityLib} from "../lib/reference-implementation/src/libraries/ModuleEntityLib.sol";
import {ModuleEntity, ValidationConfig} from "../lib/reference-implementation/src/interfaces/IModularAccount.sol";
import {SingleSignerValidationModule} from
    "../lib/reference-implementation/src/modules/validation/SingleSignerValidationModule.sol";
import {IModularAccount} from "../lib/reference-implementation/src/interfaces/IModularAccount.sol";
import {ValidationConfigLib} from "../lib/reference-implementation/src/libraries/ValidationConfigLib.sol";
import {SubscriptionModule} from "../src/SubscriptionModule.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import "./TestHelper.t.sol";

contract SubscriptionModuleTest is Test {
    SubscriptionModule public subscriptionModule;
    ReferenceModularAccount public modularAccount;
    ModuleEntity public ssvModuleEntity;

    uint32 public ENTITY_ID = type(uint32).max;
    uint8 public constant GLOBAL_VALIDATION = 1;
    uint8 public constant RESERVED_VALIDATION_DATA_INDEX = type(uint8).max;

    address public service;

    TestHelper public th;
    TestHelperVars public thv;

    function setUp() public {
        th = new TestHelper();
        thv = th.getTestVars();

        SingleSignerValidationModule ssvModule = new SingleSignerValidationModule();

        SingleSignerFactoryFixture ssFactory = new SingleSignerFactoryFixture(thv.entryPoint, ssvModule);

        modularAccount = ssFactory.createAccount(thv.config.wallet, vm.randomUint());
        vm.deal(address(modularAccount), 1e18);

        subscriptionModule = new SubscriptionModule();

        ssvModuleEntity = ModuleEntityLib.pack(address(ssvModule), ENTITY_ID);
        ModuleEntity subModuleEntity = ModuleEntityLib.pack(address(subscriptionModule), ENTITY_ID);

        ExecutionManifest memory manifest = subscriptionModule.executionManifest();

        bytes[] memory hooks = new bytes[](0);

        bytes4[] memory ssSelectors = new bytes4[](1);
        ssSelectors[0] = IModularAccount.execute.selector;

        ValidationConfig ssValidationConfig = ValidationConfigLib.pack(ssvModuleEntity, true, false, true);

        bytes4[] memory subSelectors = new bytes4[](2);
        subSelectors[0] = SubscriptionModule.subscribe.selector;
        subSelectors[1] = SubscriptionModule.paySubscription.selector;

        ValidationConfig subValidationConfig = ValidationConfigLib.pack(subModuleEntity, true, false, true);

        vm.startPrank(address(thv.entryPoint));

        modularAccount.installExecution(address(subscriptionModule), manifest, "");
        modularAccount.installValidation(subValidationConfig, subSelectors, "", hooks);
        modularAccount.installValidation(ssValidationConfig, ssSelectors, "", hooks);

        vm.stopPrank();

        service = makeAddr("service");
    }

    function testSubscribe() public {
        bytes memory subscribeCallData = abi.encodeWithSelector(SubscriptionModule.subscribe.selector, service, 100);

        bytes memory executeCallData =
            abi.encodeCall(ReferenceModularAccount.execute, (address(subscriptionModule), 0, subscribeCallData));

        (PackedUserOperation memory packedUserOp,) =
            th.getTestUserOpData(address(modularAccount), "", executeCallData, address(0));

        bytes32 r;
        bytes32 s;
        uint8 v;

        bytes memory packedSignature = packedUserOp.signature;

        assembly {
            r := mload(add(packedSignature, 0x20))
            s := mload(add(packedSignature, 0x40))
            v := byte(0, mload(add(packedSignature, 0x60)))
        }

        packedUserOp.signature = abi.encodePacked(
            abi.encodePacked(ssvModuleEntity, GLOBAL_VALIDATION),
            "",
            abi.encodePacked(RESERVED_VALIDATION_DATA_INDEX, abi.encodePacked(r, s, v))
        );

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        vm.startPrank(thv.config.wallet);

        thv.entryPoint.handleOps(ops, payable(thv.config.wallet));

        (uint256 amount,,) = subscriptionModule.subscriptions(service, address(modularAccount));
        assertEq(amount, 100);

        vm.stopPrank();
    }

    function testPaySubscription() public {
        this.testSubscribe();

        vm.startPrank(address(modularAccount));
        skip(4 weeks);

        subscriptionModule.paySubscription(service, 100);

        assertEq(service.balance, 100);
    }
}
