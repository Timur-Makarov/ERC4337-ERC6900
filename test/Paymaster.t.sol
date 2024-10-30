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
import {AccountFactory} from "../src/AccountFactory.sol";
import {IAbstractedAccount} from "../src/IAbstractedAccount.sol";
import "../src/Paymaster.sol";
import "./TestHelper.t.sol";

contract PaymasterTest is Test {
    TestHelper public th;
    TestHelperVars public thv;

    function setUp() public {
        th = new TestHelper();
        thv = th.getTestVars();
        vm.deal(thv.config.wallet, 100e18);
    }

    function testPaymasterSignatureValidation() public {
        (PackedUserOperation memory packedUserOp,) = th.getTestUserOpData(thv.accAddress, "", "", thv.pmAddress);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        IEntryPoint entryPoint = IEntryPoint(thv.config.entryPoint);

        vm.prank(thv.config.wallet);

        entryPoint.depositTo{value: 1e18}(thv.pmAddress);
        uint256 depositedBalance = entryPoint.balanceOf(thv.pmAddress);
        assertEq(depositedBalance, 1e18);

        entryPoint.handleOps(ops, payable(thv.config.wallet));
        assertEq(thv.erc20.balanceOf(thv.accAddress), 100);

        depositedBalance = entryPoint.balanceOf(thv.pmAddress);
        assertNotEq(depositedBalance, 1e18);
    }
}
