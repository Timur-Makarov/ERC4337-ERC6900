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

library TestHelperLib {
    struct TestHelperVars {
        SetupHelper.NetworkConfig config;
        AbstractedAccount account;
        ERC20Mock erc20;
        PackedUserOpHelper packedUserOpHelper;
        Paymaster paymaster;
        AccountFactory factory;
        address pmAddress;
        address accAddress;
    }
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
        address pm
    )
        public
        returns (PackedUserOperation memory, bytes32)
    {
        bytes memory executeCallData;

        {
            address dest = address(erc20);
            uint256 value = 0;
            bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, acc, 100);
            executeCallData = abi.encodeWithSelector(AbstractedAccount.execute.selector, dest, value, data);
        }

        uint256 nonce = getAccountNonce(acc);

        PackedUserOperation memory packedUserOp =
            packedUserOpHelper.generateSignedUserOperation(executeCallData, acc, networkConfig, nonce, initCode, pm);

        bytes32 userOpHash = IEntryPoint(networkConfig.entryPoint).getUserOpHash(packedUserOp);

        return (packedUserOp, userOpHash);
    }

    function getTestVars() public view returns (TestHelperLib.TestHelperVars memory) {
        return TestHelperLib.TestHelperVars({
            paymaster: paymaster,
            packedUserOpHelper: packedUserOpHelper,
            account: account,
            factory: factory,
            erc20: erc20,
            config: networkConfig,
            pmAddress: address(paymaster),
            accAddress: address(account)
        });
    }
}
