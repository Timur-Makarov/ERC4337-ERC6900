// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AbstractedAccount} from "../src/AbstractedAccount.sol";
import {AccountFactory} from "../src/AccountFactory.sol";
import {IAbstractedAccount} from "../src/IAbstractedAccount.sol";
import {AccountsDeployer} from "../script/AbstractedAccount.s.sol";
import {ERC20Mock} from "../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {SetupHelper} from "../script/SetupHelper.s.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {PackedUserOpHelper} from "../script/PackedUserOpHelper.s.sol";
import {PackedUserOperation} from "../lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ECDSA} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {IEntryPoint} from "../lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {console} from "../lib/forge-std/src/console.sol";

contract AccountTest is Test {
    SetupHelper.NetworkConfig public networkConfig;
    AbstractedAccount public account;
    AccountFactory public factory;
    ERC20Mock public erc20;
    PackedUserOpHelper public packedUserOpHelper;

    function setUp() public {
        SetupHelper setupHelper = new SetupHelper();
        networkConfig = setupHelper.getNetworkConfig();

        AccountsDeployer accountsDeployer = new AccountsDeployer();
        account = accountsDeployer.deployAccount(networkConfig);
        factory = accountsDeployer.deployAccountFactory();

        erc20 = new ERC20Mock();
        packedUserOpHelper = new PackedUserOpHelper();
    }

    function getAccountNonce(address addr) public view returns (uint256) {
        return IEntryPoint(networkConfig.entryPoint).getNonce(addr, 0);
    }

    function getTestUserOpData(address acc, bytes memory initCode, address pm)
        public
        returns (PackedUserOperation memory, bytes32)
    {
        address dest = address(erc20);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, acc, 100);
        bytes memory executeCallData = abi.encodeWithSelector(AbstractedAccount.execute.selector, dest, value, data);

        uint256 nonce = getAccountNonce(acc);

        PackedUserOperation memory packedUserOp =
            packedUserOpHelper.generateSignedUserOperation(executeCallData, acc, networkConfig, nonce, initCode, pm);

        bytes32 userOpHash = IEntryPoint(networkConfig.entryPoint).getUserOpHash(packedUserOp);

        return (packedUserOp, userOpHash);
    }

    function testOnlyEntryPointCanExecute() public {
        address dest = address(erc20);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, address(account), 100);

        vm.prank(account.owner());
        vm.expectRevert(AbstractedAccount.AbstractedAccount_NotFromEntryPoint.selector);
        account.execute(dest, value, data);
        vm.stopPrank();
    }

    function testRecoverSignedOp() public {
        (PackedUserOperation memory packedUserOp, bytes32 userOpHash) =
            getTestUserOpData(address(account), "", address(0));

        bytes32 eip191 = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address actualSigner = ECDSA.recover(eip191, packedUserOp.signature);

        assertEq(actualSigner, account.owner());
    }

    function testUserOpValidation() public {
        (PackedUserOperation memory packedUserOp, bytes32 userOpHash) =
            getTestUserOpData(address(account), "", address(0));

        vm.prank(networkConfig.entryPoint);
        uint256 validationData = account.validateUserOp(packedUserOp, userOpHash, 1e9);
        assertEq(validationData, 0);
        vm.stopPrank();
    }

    function testEntryPointCanExecuteCommands() public {
        (PackedUserOperation memory packedUserOp,) = getTestUserOpData(address(account), "", address(0));

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        vm.deal(address(account), 1e18);

        address randomUser = vm.randomAddress();
        // Random user or the owner of the AA contact - only the signature matters
        vm.prank(randomUser);
        IEntryPoint(networkConfig.entryPoint).handleOps(ops, payable(account.owner()));
        assertEq(erc20.balanceOf(address(account)), 100);
        vm.stopPrank();
    }

    function testFactoryAccountCreation() public {
        address newAccount = factory.createAccount(networkConfig.wallet, networkConfig.entryPoint);

        vm.prank(IAbstractedAccount(newAccount).owner());
        vm.expectRevert(AbstractedAccount.AbstractedAccount_NotFromEntryPoint.selector);
        IAbstractedAccount(newAccount).execute(address(0), 0, "");
        vm.stopPrank();
    }

    function testFactoryAccountCreationViaEntryPoint() public {
        uint256 factoryNonce = vm.getNonce(address(factory));
        address accountToBe = vm.computeCreateAddress(address(factory), factoryNonce);
        bytes memory initCode = abi.encodeWithSelector(
            AccountFactory.createAccount.selector, networkConfig.wallet, networkConfig.entryPoint
        );
        initCode = abi.encodePacked(address(factory), initCode);

        (PackedUserOperation memory packedUserOp, bytes32 userOpHash) =
            getTestUserOpData(accountToBe, initCode, address(0));

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        vm.deal(accountToBe, 1e18);

        vm.prank(networkConfig.wallet);
        IEntryPoint(networkConfig.entryPoint).handleOps(ops, payable(networkConfig.wallet));
        assertEq(erc20.balanceOf(address(accountToBe)), 100);
        vm.stopPrank();
    }
}
