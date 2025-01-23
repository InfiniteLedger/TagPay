// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {TagStream} from "./TagStream.sol";

contract ReceiverSuperfluidContract {
    ISuperToken public immutable acceptedToken;
    address public immutable tagStream;

    constructor(address _acceptedToken, address _tagStream) {
        acceptedToken = ISuperToken(_acceptedToken);
        tagStream = _tagStream;
    }

    function connectToRepo(string memory repo) external {
        SuperTokenV1Library.connectPool(
            acceptedToken,
            TagStream(tagStream).repoPools(repo)
        );
    }

    // TODO: verify caller is the owner of GitHub account via OAuth
    function claimRewards() external {
        uint256 amount = acceptedToken.balanceOf(address(this));
        acceptedToken.downgradeTo(msg.sender, amount);
    }
} 
