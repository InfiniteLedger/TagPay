// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";

contract EmptySuperfluidContract {
    ISuperToken public immutable acceptedToken;

    constructor(address _acceptedToken) {
        acceptedToken = ISuperToken(_acceptedToken);
    }
} 