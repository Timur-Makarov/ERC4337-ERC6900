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
import {PaymasterDeployer} from "../script/Paymaster.s.sol";
import {SetupHelper} from "../script/SetupHelper.s.sol";
import {AbstractedAccount} from "../src/AbstractedAccount.sol";
import {AccountFactory} from "../src/AccountFactory.sol";
import {IAbstractedAccount} from "../src/IAbstractedAccount.sol";
import "../src/Paymaster.sol";

struct TestHelperVars {
    SetupHelper.NetworkConfig config;
    AbstractedAccount account;
    ERC20Mock erc20;
    PackedUserOpHelper packedUserOpHelper;
    Paymaster paymaster;
    AccountFactory factory;
    IEntryPoint entryPoint;
    address pmAddress;
    address accAddress;
}

contract TestHelper {
    SetupHelper.NetworkConfig public networkConfig;
    AbstractedAccount public account;
    AccountFactory public factory;
    ERC20Mock public erc20;
    PackedUserOpHelper public packedUserOpHelper;
    Paymaster public paymaster;

    constructor() {
        SetupHelper setupHelper = new SetupHelper();
        networkConfig = setupHelper.getNetworkConfig();

        AccountsDeployer accountsDeployer = new AccountsDeployer();
        account = accountsDeployer.deployAccount(networkConfig);
        factory = accountsDeployer.deployAccountFactory();

        PaymasterDeployer paymasterDeployer = new PaymasterDeployer();
        paymaster = paymasterDeployer.deployPaymaster(networkConfig);

        erc20 = new ERC20Mock();
        packedUserOpHelper = new PackedUserOpHelper();
    }

    function getAccountNonce(address addr) public view returns (uint256) {
        return IEntryPoint(networkConfig.entryPoint).getNonce(addr, 0);
    }

    function getTestUserOpData(
        address acc,
        bytes memory initCode,
        bytes memory executeCallData,
        address pm
    )
        public
        returns (PackedUserOperation memory, bytes32)
    {
        if (executeCallData.length == 0) {
            address dest = address(erc20);
            bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, acc, 100);
            executeCallData = abi.encodeWithSelector(AbstractedAccount.execute.selector, dest, 0, data);
        }

        PackedUserOperation memory packedUserOp = packedUserOpHelper.generateSignedUserOperation(
            executeCallData, acc, networkConfig, getAccountNonce(acc), initCode, pm
        );

        bytes32 userOpHash = IEntryPoint(networkConfig.entryPoint).getUserOpHash(packedUserOp);

        return (packedUserOp, userOpHash);
    }

    function getTestVars() public view returns (TestHelperVars memory) {
        return TestHelperVars({
            paymaster: paymaster,
            packedUserOpHelper: packedUserOpHelper,
            account: account,
            factory: factory,
            erc20: erc20,
            config: networkConfig,
            entryPoint: IEntryPoint(networkConfig.entryPoint),
            pmAddress: address(paymaster),
            accAddress: address(account)
        });
    }
}
