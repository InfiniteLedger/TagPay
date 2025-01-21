// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {SuperfluidFrameworkDeployer} from "@superfluid-finance/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeployer.sol";
import {ERC1820RegistryCompiled} from "@superfluid-finance/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";
import "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperTokenFactory.sol";
import "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {TagStream} from "../src/TagStream.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract TagStreamTest is Test {
    TagStream internal tagStream;
    SuperfluidFrameworkDeployer.Framework internal sf;
    IERC20Metadata internal underlyingAcceptedToken;
    ISuperToken internal acceptedToken;

    string internal repo1 = "repo1";
    string internal dev1 = "dev1";
    string internal dev2 = "dev2";

    using SuperTokenV1Library for ISuperToken;

    function setUp() public {
        vm.etch(ERC1820RegistryCompiled.at, ERC1820RegistryCompiled.bin);
        SuperfluidFrameworkDeployer sfDeployer = new SuperfluidFrameworkDeployer();
        sfDeployer.deployTestFramework();
        sf = sfDeployer.getFramework();

        underlyingAcceptedToken = new MockERC20("Mock Token", "MTK");

        ISuperTokenFactory superTokenFactory = sf.superTokenFactory;
        acceptedToken = ISuperToken(
            superTokenFactory.createERC20Wrapper(
                underlyingAcceptedToken,
                ISuperTokenFactory.Upgradability.SEMI_UPGRADABLE,
                "Super Mock Token",
                "MTKx"
            )
        );

        tagStream = new TagStream(address(acceptedToken));
    }

    function test_GivingUnits() public {
        console.log("Test started");
        
        string[] memory developers = new string[](2);
        developers[0] = dev1;
        developers[1] = dev2;
        console.log("Developers array created");
        
        uint128[] memory units = new uint128[](2);
        units[0] = 10;
        units[1] = 20;
        console.log("Units array created");
        
        console.log("About to call giveUnitsToRepoContributors");
        tagStream.giveUnitsToRepoContributors(repo1, developers, units);
        console.log("Call completed");

        address dev1Receiver = tagStream.receiverContracts(dev1);
        address dev2Receiver = tagStream.receiverContracts(dev2);

        assert(tagStream.repoPools(repo1).getUnits(dev1Receiver) == 10);
        assert(tagStream.repoPools(repo1).getUnits(dev2Receiver) == 20);
    }
}
