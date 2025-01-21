// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISETH} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/tokens/ISETH.sol";
import {ISuperfluidPool, PoolConfig} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";

import {EmptySuperfluidContract} from "./EmptySuperfluidContract.sol";

contract TagStream {
    address public owner;
    using SuperTokenV1Library for ISuperToken;
    ISuperToken public acceptedToken;
    IERC20 public underlyingToken;
    PoolConfig private poolConfig;

    // use this to get the pool for a repo
    mapping(string => ISuperfluidPool) public repoPools;
    mapping(string => bool) public repoPoolsCreated;
    // use this to get the receiver contract for a developer
    mapping(string => address) public receiverContracts;

    modifier onlyOwner() {
        require(owner == msg.sender, "Only Owner");
        _;
    }

    /**
     * @dev Creates a contract tied to the specified Super Token
     * @param _acceptedToken Super token address
     * @notice You can find the address of your Super Token on the explorer: https://explorer.superfluid.finance
     */
    constructor(address _acceptedToken) {
        owner = msg.sender;
        acceptedToken = ISuperToken(_acceptedToken);
        underlyingToken = IERC20(acceptedToken.getUnderlyingToken());
        poolConfig.transferabilityForUnitsOwner = false;
        poolConfig.distributionFromAnyAddress = false;
    }

    /**
     * @dev Allocates an array of units to an array of members in a pool
     * @param _members The array of members
     * @param _units The array of units
     * @notice The method `updateMemberUnits` DOES NOT add units to a member but rather sets the units amount
     */
    function giveUnits(
        ISuperfluidPool pool,
        address[] memory _members,
        uint128[] memory _units
    ) public onlyOwner {
        // Make sure your for loop does not exceed the gas limit
        for (uint256 i = 0; i < _members.length; i++) {
            pool.updateMemberUnits(_members[i], _units[i]);
        }
    }

    /**
     * @dev Creates an streaming distribution to all the members of the pool
     * @param _amount The amount of tokens to distribute (in Wei or equivalent)
     * @param _duration the duration of your distribution (in seconds)
     * @notice Make sure the contract has enough allowance of the ERC-20 to allow the `transferFrom`
     */
    function flowDistribute(
        ISuperfluidPool pool,
        uint _amount,
        uint _duration
    ) external onlyOwner {
        underlyingToken.transferFrom(msg.sender, address(this), _amount);
        acceptedToken.upgrade(_amount);
        int96 _flowRate = int96(int256(_amount / _duration));
        acceptedToken.flowX(address(pool), _flowRate);
    }

    /**
     * @dev Removes a list of members from the pool
     * @param _members The array of members
     * @notice Deleting a member from the pool is simply assigning 0 units to them using the method `updateMemberUnits`
     */
    function deleteMembersFromPool(
        ISuperfluidPool pool,
        address[] memory _members
    ) external onlyOwner {
        for (uint256 i = 0; i < _members.length; i++) {
            pool.updateMemberUnits(_members[i], 0);
        }
    }

    function createOrGetRepoPool(
        string memory repoId
    ) public returns (ISuperfluidPool) {
        if (!repoPoolsCreated[repoId]) {
            repoPools[repoId] = acceptedToken.createPool(
                address(this),
                poolConfig
            );
            repoPoolsCreated[repoId] = true;
        }
        return repoPools[repoId];
    }

    // TODO: consider creating a receiver contract for other dependent repos
    function getOrCreateReceiverContract(
        string memory developerId
    ) internal returns (address) {
        if (receiverContracts[developerId] == address(0)) {
            receiverContracts[developerId] = address(
                new EmptySuperfluidContract(address(acceptedToken))
            );
        }
        return receiverContracts[developerId];
    }

    function giveUnitsToRepoContributors(
        string memory repoId,
        string[] memory developerId,
        uint128[] memory units
    ) external {
        ISuperfluidPool pool = createOrGetRepoPool(repoId);
        address[] memory members = new address[](developerId.length);
        for (uint256 i = 0; i < developerId.length; i++) {
            address receiverContract = getOrCreateReceiverContract(
                developerId[i]
            );
            members[i] = receiverContract;
        }
        giveUnits(pool, members, units);
    }
}
