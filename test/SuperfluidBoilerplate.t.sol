// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "forge-std/Test.sol";
import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperfluidFrameworkDeployer } from "@superfluid-finance/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeployer.sol";
import { ERC1820RegistryCompiled } from "@superfluid-finance/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";
import "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperTokenFactory.sol";
import "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {SuperfluidBoilerplate} from "../src/SuperfluidBoilerplate.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";


contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**decimals());
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract SuperfluidBoilerplateTest is Test {
	SuperfluidBoilerplate internal superfluidBoilerplate;
	SuperfluidFrameworkDeployer.Framework internal sf;
    IERC20Metadata internal underlyingAcceptedToken;
    ISuperToken internal acceptedToken;
    address internal alice;
    address internal bob;

    using SuperTokenV1Library for ISuperToken;

    function setUp() public {
        vm.etch(ERC1820RegistryCompiled.at, ERC1820RegistryCompiled.bin);
		SuperfluidFrameworkDeployer sfDeployer = new SuperfluidFrameworkDeployer();
		sfDeployer.deployTestFramework();
		sf = sfDeployer.getFramework();

        underlyingAcceptedToken = new MockERC20("Mock Token", "MTK");

        ISuperTokenFactory superTokenFactory=sf.superTokenFactory;
        acceptedToken = ISuperToken(superTokenFactory.createERC20Wrapper(
            underlyingAcceptedToken,
            ISuperTokenFactory.Upgradability.SEMI_UPGRADABLE,
            "Super Mock Token",
            "MTKx"
        ));

        superfluidBoilerplate= new SuperfluidBoilerplate(address(acceptedToken));
    }

    function test_CreateUpdateDeleteFlow() public {
        underlyingAcceptedToken.approve(address(acceptedToken), type(uint256).max);
        acceptedToken.upgrade(underlyingAcceptedToken.balanceOf(address(this)));
        acceptedToken.transferX(address(superfluidBoilerplate),acceptedToken.balanceOf(address(this)));

        alice = address(0x1);

        superfluidBoilerplate.createUpdateDeleteFlow(alice, 100);
        int96 aliceFlowRate=acceptedToken.getFlowRate(address(superfluidBoilerplate), alice);
        assert(aliceFlowRate==200);
    }

    /*function test_GivingUnits() public {

        alice=address(0x1);
        bob=address(0x2);

        superfluidBoilerplate.giveUnits([alice,bob], [10,20]);

        assert(superfluidBoilerplate.pool().getUnits(alice)==10);
        assert(superfluidBoilerplate.pool().getUnits(bob)==20);
    }*/

    // The rest of tests


}
