// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISETH} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/tokens/ISETH.sol";
import {ISuperfluidPool, PoolConfig} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";

import {ReceiverSuperfluidContract} from "./ReceiverSuperfluidContract.sol";

contract TagStream {
    address public owner;
    using SuperTokenV1Library for ISuperToken;
    ISuperToken public acceptedToken;
    IERC20 public underlyingToken;
    PoolConfig private poolConfig;

    // TODO: maybe create a struct for repo
    // struct Repo {
    //     string id;
    //     string name;
    //     string description;
    // }
    // mapping(string => Repo) public repos;

    // use this to get the pool for a repo
    mapping(string => ISuperfluidPool) public repoPools;
    mapping(string => bool) public repoPoolsCreated;

    // use this to get the receiver contract for a developer
    mapping(string => address) public receiverContracts;
    // use this to get the developer's pools
    mapping(string => string[]) public developerRepos;
    // TODO: find a better way to deal with it. Need both list to return and mapping to check if the pool is pushed.
    mapping(string => mapping(string => bool)) public developerRepoPushed;

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
    function _giveUnits(
        ISuperfluidPool pool,
        address[] memory _members,
        uint128[] memory _units
    ) internal {
        // Make sure your for loop does not exceed the gas limit
        for (uint256 i = 0; i < _members.length; i++) {
            pool.updateMemberUnits(_members[i], _units[i]);
        }
    }

    // should not be public method?
    function flowToRepo(
        string memory repoId,
        uint _amount,
        uint _duration
    ) external {
        ISuperfluidPool pool = _createOrGetRepoPool(repoId);
        int96 flowRate = int96(int256(_amount / _duration));
        acceptedToken.flowX(address(pool), flowRate);
    }

    /**
     * @dev Creates an streaming distribution to all the members of the pool
     * @param repoId the id of the repo to distribute to
     * @param _amount The amount of tokens to distribute (in Wei or equivalent)
     * @param _duration the duration of your distribution (in seconds)
     */
    function flowDistributeToRepo(
        string memory repoId,
        uint _amount,
        uint _duration
    ) external onlyOwner {
        ISuperfluidPool pool = _createOrGetRepoPool(repoId);
        _flowDistribute(pool, _amount, _duration);
    }

    /**
     * @dev Creates an streaming distribution to all the members of the pool
     * @param pool the pool to distribute to
     * @param _amount The amount of tokens to distribute (in Wei or equivalent)
     * @param _duration the duration of your distribution (in seconds)
     * @notice Make sure the contract has enough allowance of the ERC-20 to allow the `transferFrom`
     */
    function _flowDistribute(
        ISuperfluidPool pool,
        uint _amount,
        uint _duration
    ) internal onlyOwner {
        underlyingToken.transferFrom(msg.sender, address(this), _amount);
        underlyingToken.approve(address(acceptedToken), _amount);
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

    function _createOrGetRepoPool(
        string memory repoId
    ) internal returns (ISuperfluidPool) {
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
    function _getOrCreateReceiverContract(
        string memory developerId
    ) internal returns (address) {
        if (receiverContracts[developerId] == address(0)) {
            receiverContracts[developerId] = address(
                new ReceiverSuperfluidContract(
                    address(acceptedToken),
                    address(this),
                    address(owner)
                )
            );
        }
        return receiverContracts[developerId];
    }

    function giveUnitsForRepo(
        string memory repoId,
        string[] memory developerIds,
        uint128[] memory developerUnits,
        string[] memory dependentRepoIds,
        uint128[] memory dependentUnits
    ) external onlyOwner {
        ISuperfluidPool pool = _createOrGetRepoPool(repoId);
        address[] memory members = new address[](developerIds.length);
        address[] memory dependentMembers = new address[](
            dependentRepoIds.length
        );

        for (uint256 i = 0; i < developerIds.length; i++) {
            address receiverContract = _getOrCreateReceiverContract(
                developerIds[i]
            );
            members[i] = receiverContract;
            if (!developerRepoPushed[developerIds[i]][repoId]) {
                developerRepos[developerIds[i]].push(repoId);
                developerRepoPushed[developerIds[i]][repoId] = true;
            }
        }
        _giveUnits(pool, members, developerUnits);

        for (uint256 i = 0; i < dependentRepoIds.length; i++) {
            _createOrGetRepoPool(dependentRepoIds[i]);
            dependentMembers[i] = _getOrCreateReceiverContract(
                dependentRepoIds[i]
            );
        }
        _giveUnits(pool, dependentMembers, dependentUnits);
    }

    function getDeveloperRepos(
        string memory developerId
    ) public view returns (string[] memory) {
        return developerRepos[developerId];
    }

    function getReceiverContract(
        string memory developerId
    ) public view returns (address) {
        return receiverContracts[developerId];
    }
}
