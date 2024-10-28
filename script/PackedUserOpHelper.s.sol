// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IEntryPoint} from "../lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "../lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Script} from "../lib/forge-std/src/Script.sol";

import {console} from "../lib/forge-std/src/console.sol";
import {EIP712} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import {MessageHashUtils} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {SetupHelper} from "./SetupHelper.s.sol";

contract PackedUserOpHelper is Script {
    bytes32 public constant SIGNATURE_TYPEHASH =
        keccak256("Paymaster(address sender,uint256 timeToExpiration,uint256 nonce)");

    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    function run() public {}

    function generateSignedUserOperation(
        bytes memory callData,
        address sender,
        SetupHelper.NetworkConfig memory config,
        uint256 nonce,
        bytes memory initCode,
        address paymaster
    )
        public
        returns (PackedUserOperation memory)
    {
        PackedUserOperation memory userOp = _generateUnsignedUserOperation(callData, sender, nonce, initCode);
        SetupHelper setupHelper = new SetupHelper();

        if (paymaster != address(0)) {
            {
                uint256 timeToExpiration = vm.getBlockTimestamp() + 12 * 5;

                bytes32 hash = keccak256(abi.encode(SIGNATURE_TYPEHASH, sender, timeToExpiration, nonce));
                bytes32 digest = _hashTypedDataV4(paymaster, hash);

                uint8 v;
                bytes32 r;
                bytes32 s;

                if (block.chainid == setupHelper.ANVIL_CHAIN_ID()) {
                    (, uint256 key) = makeAddrAndKey("paymaster");

                    (v, r, s) = vm.sign(key, digest);
                } else {
                    (v, r, s) = vm.sign(config.paymasterSignerWallet, digest);
                }

                uint128 validationGasLimit = 16777216;
                uint128 postOpGasLimit = 200000;

                userOp.paymasterAndData =
                    abi.encodePacked(paymaster, validationGasLimit, postOpGasLimit, timeToExpiration, r, s, v);
            }
        }

        {
            bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
            bytes32 digest = MessageHashUtils.toEthSignedMessageHash(userOpHash);

            uint8 v;
            bytes32 r;
            bytes32 s;

            if (block.chainid == setupHelper.ANVIL_CHAIN_ID()) {
                (v, r, s) = vm.sign(setupHelper.ANVIL_WALLET_KEY(), digest);
            } else {
                (v, r, s) = vm.sign(config.wallet, digest);
            }

            userOp.signature = abi.encodePacked(r, s, v);
        }

        return userOp;
    }

    function _generateUnsignedUserOperation(
        bytes memory callData,
        address sender,
        uint256 nonce,
        bytes memory initCode
    )
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;

        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: initCode,
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: "",
            signature: ""
        });
    }

    function _buildDomainSeparator(address paymaster) private view returns (bytes32) {
        return keccak256(
            abi.encode(DOMAIN_TYPEHASH, keccak256(bytes("Paymaster")), keccak256(bytes("1")), block.chainid, paymaster)
        );
    }

    function _hashTypedDataV4(address paymaster, bytes32 structHash) internal view virtual returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(_buildDomainSeparator(paymaster), structHash);
    }
}
