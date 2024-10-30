// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IEntryPoint} from "../lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "../lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {ERC20Mock} from "../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {ECDSA} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {AccountsDeployer} from "../script/AbstractedAccount.s.sol";
import {PackedUserOpHelper} from "../script/PackedUserOpHelper.s.sol";
import {SetupHelper} from "../script/SetupHelper.s.sol";
import {AbstractedAccount} from "../src/AbstractedAccount.sol";
import {AccountFactory} from "../src/AccountFactory.sol";
import {IAbstractedAccount} from "../src/IAbstractedAccount.sol";
import "./TestHelper.t.sol";

contract AccountTest is Test {
    TestHelper public th;
    TestHelperVars public thv;

    function setUp() public {
        th = new TestHelper();
        thv = th.getTestVars();
        vm.deal(thv.config.wallet, 100e18);
    }

    function testOnlyEntryPointCanExecute() public {
        address dest = address(thv.erc20);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, thv.accAddress, 100);

        vm.prank(thv.config.wallet);

        vm.expectRevert(AbstractedAccount.AbstractedAccount_NotFromEntryPoint.selector);
        thv.account.execute(dest, value, data);
    }

    function testRecoverSignedOp() public {
        (PackedUserOperation memory packedUserOp, bytes32 userOpHash) =
            th.getTestUserOpData(thv.accAddress, "", "", address(0));

        bytes32 eip191 = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address actualSigner = ECDSA.recover(eip191, packedUserOp.signature);

        assertEq(actualSigner, thv.account.owner());
    }

    function testUserOpValidation() public {
        (PackedUserOperation memory packedUserOp, bytes32 userOpHash) =
            th.getTestUserOpData(thv.accAddress, "", "", address(0));

        vm.prank(thv.config.entryPoint);

        uint256 validationData = thv.account.validateUserOp(packedUserOp, userOpHash, 1e9);
        assertEq(validationData, 0);
    }

    function testEntryPointCanExecuteCommands() public {
        (PackedUserOperation memory packedUserOp,) = th.getTestUserOpData(thv.accAddress, "", "", address(0));

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        vm.deal(thv.accAddress, 1e18);

        vm.prank(thv.config.wallet);

        IEntryPoint(thv.config.entryPoint).handleOps(ops, payable(thv.account.owner()));
        assertEq(thv.erc20.balanceOf(thv.accAddress), 100);
    }

    function testFactoryAccountCreation() public {
        address newAccount = thv.factory.createAccount(thv.config.wallet, thv.config.entryPoint);

        vm.prank(thv.config.wallet);

        vm.expectRevert(AbstractedAccount.AbstractedAccount_NotFromEntryPoint.selector);
        IAbstractedAccount(newAccount).execute(address(0), 0, "");
    }

    function testFactoryAccountCreationViaEntryPoint() public {
        uint256 factoryNonce = vm.getNonce(address(thv.factory));
        address accountToBe = vm.computeCreateAddress(address(thv.factory), factoryNonce);

        bytes memory initCode =
            abi.encodeWithSelector(AccountFactory.createAccount.selector, thv.config.wallet, thv.config.entryPoint);

        initCode = abi.encodePacked(address(thv.factory), initCode);

        (PackedUserOperation memory packedUserOp,) = th.getTestUserOpData(accountToBe, initCode, "", address(0));

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        vm.deal(accountToBe, 1e18);

        vm.prank(thv.config.wallet);

        IEntryPoint(thv.config.entryPoint).handleOps(ops, payable(thv.config.wallet));
        assertEq(thv.erc20.balanceOf(address(accountToBe)), 100);
    }
}
