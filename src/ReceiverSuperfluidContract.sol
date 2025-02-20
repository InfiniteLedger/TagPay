// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {TagStream} from "./TagStream.sol";

contract ReceiverSuperfluidContract {
    using SuperTokenV1Library for ISuperToken;
    ISuperToken public immutable acceptedToken;
    address public immutable tagStream;
    address public immutable superAdmin;
    address public receiver;

    constructor(
        address _acceptedToken,
        address _tagStream,
        address _superAdmin
    ) {
        acceptedToken = ISuperToken(_acceptedToken);
        tagStream = _tagStream;
        superAdmin = _superAdmin;
    }

    function setReceiver(address _receiver) external {
        require(
            msg.sender == tagStream ||
                msg.sender == superAdmin ||
                msg.sender == receiver,
            "Only TagStream or SuperAdmin or Stream Receiver can set Receiver"
        );
        receiver = _receiver;
    }

    function connectToRepo(string memory repo) public {
        acceptedToken.connectPool(TagStream(tagStream).repoPools(repo));
    }

    function claimRewards() external {
        require(
            msg.sender == receiver,
            "Only Stream Receiver can claim rewards"
        );
        uint256 amount = acceptedToken.balanceOf(address(this));
        acceptedToken.downgradeTo(msg.sender, amount);
    }

    // flow from source repo to target repo
    function flowToRepo(
        string memory sourceRepo,
        string memory targetRepo,
        uint _amount,
        uint _duration
    ) external {
        // connect to source repo
        connectToRepo(sourceRepo);
        // flow to target repo
        TagStream(tagStream).flowToRepo(targetRepo, _amount, _duration);
    }
}
