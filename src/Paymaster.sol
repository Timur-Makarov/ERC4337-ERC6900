// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPaymaster} from "../lib/account-abstraction/contracts/interfaces/IPaymaster.sol";
import {PackedUserOperation} from "../lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {MessageHashUtils} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_SUCCESS, SIG_VALIDATION_FAILED} from "../lib/account-abstraction/contracts/core/Helpers.sol";
import {UserOperationLib} from "../lib/account-abstraction/contracts/core/UserOperationLib.sol";
import {IEntryPoint} from "../lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {EIP712} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import {console} from "../lib/forge-std/src/console.sol";

contract Paymaster is IPaymaster, Ownable, EIP712 {
    error Paymaster_NotFromEntryPoint();
    error Paymaster_ExpiredSignature();

    IEntryPoint private immutable i_entryPoint;

    bytes32 public constant SIGNATURE_TYPEHASH =
        keccak256("Paymaster(address sender,uint256 timeToExpiration,uint256 nonce)");

    address public i_signer;

    constructor(address signer, address entryPoint) Ownable(msg.sender) EIP712("Paymaster", "1") {
        i_signer = signer;
        i_entryPoint = IEntryPoint(entryPoint);
    }

    modifier onlyEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert Paymaster_NotFromEntryPoint();
        }
        _;
    }

    function validatePaymasterUserOp(PackedUserOperation calldata userOp, bytes32, uint256)
        external
        onlyEntryPoint
        returns (bytes memory context, uint256 validationData)
    {
        context = new bytes(0);
        validationData = _validatePaymasterSignature(userOp);
    }

    function postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost, uint256 actualUserOpFeePerGas)
        external
    {}

    function _validatePaymasterSignature(PackedUserOperation calldata userOp)
        internal
        returns (uint256 validationData)
    {
        uint256 offset = 52;
        uint256 timeToExpiration = abi.decode(userOp.paymasterAndData[offset:offset + 32], (uint256));
        bytes32 r = abi.decode(userOp.paymasterAndData[offset + 32:offset + 64], (bytes32));
        bytes32 s = abi.decode(userOp.paymasterAndData[offset + 64:offset + 96], (bytes32));
        uint8 v = uint8(userOp.paymasterAndData[offset + 96]);

        if (timeToExpiration < block.timestamp) {
            revert Paymaster_ExpiredSignature();
        }

        bytes32 hash = keccak256(abi.encode(SIGNATURE_TYPEHASH, userOp.sender, timeToExpiration, userOp.nonce));

        address actualSigner = ECDSA.recover(_hashTypedDataV4(hash), v, r, s);

        if (actualSigner != i_signer) {
            return SIG_VALIDATION_FAILED;
        }

        return SIG_VALIDATION_SUCCESS;
    }

    function splitSignature(bytes memory signature) internal returns (bytes32 r, bytes32 s, uint8 v) {
        require(signature.length == 65, "Invalid Signature Length");
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
    }
}
