// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AbstractedAccount} from "./AbstractedAccount.sol";

contract AccountFactory {
    function createAccount(address owner, address entryPoint) external returns (address) {
        AbstractedAccount account = new AbstractedAccount(owner, entryPoint);
        return address(account);
    }
}
