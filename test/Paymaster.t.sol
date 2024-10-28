// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../src/Paymaster.sol";
import {AbstractedAccount} from "../src/AbstractedAccount.sol";
import {AccountFactory} from "../src/AccountFactory.sol";
import {AccountsDeployer} from "../script/AbstractedAccount.s.sol";
import {ECDSA} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {ERC20Mock} from "../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IAbstractedAccount} from "../src/IAbstractedAccount.sol";
import {IEntryPoint} from "../lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {PackedUserOpHelper} from "../script/PackedUserOpHelper.s.sol";
import {PackedUserOperation} from "../lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {SetupHelper} from "../script/SetupHelper.s.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {PaymasterDeployer} from "../script/Paymaster.s.sol";

contract PaymasterTest is Test {
    SetupHelper.NetworkConfig public networkConfig;
    AbstractedAccount public account;
    ERC20Mock public erc20;
    PackedUserOpHelper public packedUserOpHelper;
    Paymaster public paymaster;

    function setUp() public {
        SetupHelper setupHelper = new SetupHelper();
        networkConfig = setupHelper.getNetworkConfig();

        AccountsDeployer accountsDeployer = new AccountsDeployer();
        account = accountsDeployer.deployAccount(networkConfig);

        PaymasterDeployer paymasterDeployer = new PaymasterDeployer();
        paymaster = paymasterDeployer.deployPaymaster(networkConfig);

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

    function testPaymasterSignatureValidation() public {
        (PackedUserOperation memory packedUserOp,) = getTestUserOpData(address(account), "", address(paymaster));

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        address randomUser = vm.randomAddress();

        vm.deal(randomUser, 1.1e18);

        vm.prank(randomUser);
        IEntryPoint(networkConfig.entryPoint).depositTo{value: 1e18}(address(paymaster));
        uint256 depositedBalance = IEntryPoint(networkConfig.entryPoint).balanceOf(address(paymaster));
        assertEq(depositedBalance, 1e18);

        IEntryPoint(networkConfig.entryPoint).handleOps(ops, payable(account.owner()));
        assertEq(erc20.balanceOf(address(account)), 100);

        depositedBalance = IEntryPoint(networkConfig.entryPoint).balanceOf(address(paymaster));
        assertNotEq(depositedBalance, 1e18);
        vm.stopPrank();
    }
}
