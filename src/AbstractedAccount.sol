// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "../lib/account-abstraction/contracts/core/Helpers.sol";
import {IAccount} from "../lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {IEntryPoint} from "../lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "../lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ECDSA} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract AbstractedAccount is IAccount, Ownable {
    error AbstractedAccount_NotFromEntryPoint();
    error AbstractedAccount_FailedExecution(bytes returnData);

    IEntryPoint private immutable i_entryPoint;

    constructor(address owner, address entryPoint) Ownable(owner) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    receive() external payable {}

    modifier onlyEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert AbstractedAccount_NotFromEntryPoint();
        }
        _;
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        onlyEntryPoint
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);
        _payPrefund(missingAccountFunds);
    }

    function execute(address dest, uint256 value, bytes calldata data) external onlyEntryPoint {
        (bool success, bytes memory returnData) = dest.call{value: value}(data);
        if (!success) {
            revert AbstractedAccount_FailedExecution({returnData: returnData});
        }
    }

    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        internal
        view
        returns (uint256 validationData)
    {
        // Convert to the correct standard EIP-191
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }

        return SIG_VALIDATION_SUCCESS;
    }

    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds}("");
            (success);
        }
    }
}
