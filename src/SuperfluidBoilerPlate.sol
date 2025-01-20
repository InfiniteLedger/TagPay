// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISETH} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/tokens/ISETH.sol";
import {ISuperfluidPool, PoolConfig} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";

contract SuperfluidBoilerplate {
    address public owner;
    // The following line makes it possible to write acceptedToken.METHOD(params) instead of SuperTokenV1Library.METHOD(acceptedToken,restOfParams)
    using SuperTokenV1Library for ISuperToken;
    //In case of a native Super Token (eg. ETHx) use the following line:
    //using SuperTokenV1Library for ISETH;
    ISuperfluidPool public pool;
    ISuperToken public acceptedToken;
    //In case of a native Super Token (eg. ETHx), use the following line:
    //ISETH public acceptedToken;
    IERC20 public underlyingToken; //The underlying ERC20 in case of a wrapped SuperToken;
    PoolConfig private poolConfig;

    modifier onlyOwner(){
        require(owner==msg.sender,"Only Owner");
        _;
    }

    /**
     * @dev Creates a contract tied to the specified Super Token
     * @param _acceptedToken Super token address
     * @notice You can find the address of your Super Token on the explorer: https://explorer.superfluid.finance
     */
    
    constructor(address _acceptedToken) {
        owner = msg.sender;
        acceptedToken=ISuperToken(_acceptedToken);
        underlyingToken=IERC20(acceptedToken.getUnderlyingToken());
        //In case of a native Super Token (eg. ETHx) use ISETH like so:
        //acceptedToken = ISETH(_acceptedToken);
        poolConfig.transferabilityForUnitsOwner = false; //"False" makes the units non transferable between members. Set "true" if you want to allow the pool members to transfer their units as an ERC-20
        poolConfig.distributionFromAnyAddress = false; //"False" makes it only possible for the admin to distribute to the pool. Set "true" if you want to allow any address to distribute to the pool
        pool = acceptedToken.createPool(address(this), poolConfig); //This creates a pool with the admin being this contract
    }

    //@@@@@@@@@@@@@ Money Streaming: One-to-One Streams @@@@@@@@@@@@@//

    /**
     * @dev Creates, updates and deletes a flow to an account
     * @param _receiver The receiver (account)
     * @param _flowRate The flowRate to be set.
     * @notice This function assumes that the contract already holds some amount of the accepted Super Token
     * NEW: You will notice that we have a new function called `flowX`
     * This is a meta-method which serves the function of create/update/delete as it's shown below
     */
    function createUpdateDeleteFlow(address _receiver, int96 _flowRate) external onlyOwner {
        acceptedToken.createFlow(_receiver, _flowRate, new bytes(0));
        acceptedToken.updateFlow(_receiver, _flowRate+100, new bytes(0));
        //acceptedToken.deleteFlow(address(this), _receiver, _flowRate, new bytes(0));

        //---- NEW-NEU-NOUVEAU-NUEVO-NOVE-جديد: You can also use `flowX` which is a meta-method ----//
        acceptedToken.flowX(_receiver,_flowRate);
        acceptedToken.flowX(_receiver,_flowRate+100);
        //acceptedToken.flowX(_receiver,0);
    }

    //@@@@@@@@@@@@@ Distribution Pools: One-to-Many (or Many-to-Many) Infinitely Scalable Transfers or Streams @@@@@@@@@@@@@//

    /**
     * @dev Allocates an array of units to an array of members in a pool
     * @param _members The array of members
     * @param _units The array of units
     * @notice The method `updateMemberUnits` DOES NOT add units to a member but rather sets the units amount
     * Eg. A member can previously have 10 units, if you call `updateMemberUnits(member,20)` for that member, their new units is 20 NOT 30
     */
    function giveUnits(address[] memory _members,uint128[] memory _units) external onlyOwner {
        // Make sure your for loop does not exceed the gas limit
        for(uint256 i=0;i<_members.length;i++){
            pool.updateMemberUnits(_members[i],_units[i]);
        }
    }
    
    /**
     * @dev Creates an instant distribution to all the members of the pool
     * @param _amount The amount to distribute
     * @notice Make sure the contract has enough allowance of the ERC-20 to allow the `transferFrom` 
     * NEW: You can now use the method `transferX` for simple transfers of Super Tokens (1-to-1) or for Instant Distributions to a pool
     */
    function instantlyDistribute(uint256 _amount) external onlyOwner  {
        //In the case of a native Super Token (eg. ETHx), don't forget to make the function payable and do the following:
        //uint256 _amount = msg.value;
        underlyingToken.transferFrom(msg.sender, address(this), _amount);
        acceptedToken.upgrade(_amount); //In the case of a native Super Token, use `upgadeByEth`
        acceptedToken.distribute(address(this),pool,_amount/2);

        //---- NEW-NEU-NOUVEAU-NUEVO-NOVE-جديد: You can also use `transferX` which is a meta-method ----//
        acceptedToken.transferX(address(pool),_amount/2);
    }

    /**
     * @dev Creates an streaming distribution to all the members of the pool
     * @param _amount The amount of tokens to distribute (in Wei or equivalent)
     * @param _duration the duration of your distribution (in seconds)
     * @notice Make sure the contract has enough allowance of the ERC-20 to allow the `transferFrom` 
     * NEW: You can now use the method `flowX` for the management of simple flows of Super Tokens (1-to-1) or for Streaming Distributions to a pool
     */
    function flowDistribute(uint _amount, uint _duration) external onlyOwner{
        //In the case of a native Super Token (eg. ETHx), don't forget to make the function payable and do the following:
        //uint256 _amount = msg.value;
        underlyingToken.transferFrom(msg.sender, address(this), _amount);
        acceptedToken.upgrade(_amount); //In the case of a native Super Token, use `upgadeByEth`
        int96 _flowRate = int96(int256(_amount/_duration));
        acceptedToken.distributeFlow(address(this), pool, _flowRate);

        //---- NEW-NEU-NOUVEAU-NUEVO-NOVE-جديد: You can also use `flowX` which is a meta-method ----//
        acceptedToken.flowX(address(pool),_flowRate);
    }

    /**
     * @dev Removes a list of members from the pool
     * @param _members The array of members
     * @notice Deleting a member from the pool is simply assigning 0 units to them using the method `updateMemberUnits`
     */
    function deleteMembersFromPool(address[] memory _members) external onlyOwner {
        for(uint256 i=0;i<_members.length;i++){
            pool.updateMemberUnits(_members[i],0);
        }
    }
 
}