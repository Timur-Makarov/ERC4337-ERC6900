// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IAccount} from "../lib/account-abstraction/contracts/interfaces/IAccount.sol";

interface IAbstractedAccount is IAccount {
    function execute(address dest, uint256 value, bytes calldata data) external;
    function owner() external view returns (address);
}
