// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {SuperfluidFrameworkDeployer} from "@superfluid-finance/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeployer.sol";
import {ERC1820RegistryCompiled} from "@superfluid-finance/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";
import "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperTokenFactory.sol";
import "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {TagStream} from "../src/TagStream.sol";
import {ReceiverSuperfluidContract} from "../src/ReceiverSuperfluidContract.sol";

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
    MockERC20 internal underlyingAcceptedToken;
    ISuperToken internal acceptedToken;

    string internal repo1 = "repo1";
    string internal dev1 = "dev1";
    string internal dev2 = "dev2";
    address internal dev1Wallet = address(0x1);
    address internal dev2Wallet = address(0x2);

    using SuperTokenV1Library for ISuperToken;

    function setUp() public {
        console.log("Setting up test", msg.sender);
        vm.etch(ERC1820RegistryCompiled.at, ERC1820RegistryCompiled.bin);
        SuperfluidFrameworkDeployer sfDeployer = new SuperfluidFrameworkDeployer();
        sfDeployer.deployTestFramework();
        sf = sfDeployer.getFramework();

        underlyingAcceptedToken = new MockERC20("Mock Token", "MTK");
        underlyingAcceptedToken.mint(address(this), 1000000 * 10 ** 18);

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
        console.log("Test started", msg.sender);

        string[] memory developers = new string[](2);
        developers[0] = dev1;
        developers[1] = dev2;
        uint128[] memory units = new uint128[](2);
        units[0] = 10;
        units[1] = 20;

        tagStream.giveUnitsToRepoContributors(repo1, developers, units);

        address dev1Receiver = tagStream.receiverContracts(dev1);
        address dev2Receiver = tagStream.receiverContracts(dev2);

        assert(tagStream.repoPools(repo1).getUnits(dev1Receiver) == 10);
        assert(tagStream.repoPools(repo1).getUnits(dev2Receiver) == 20);

        console.log("dev1 repos");
        for (uint256 i = 0; i < tagStream.getDeveloperRepos(dev1).length; i++) {
            console.log(tagStream.getDeveloperRepos(dev1)[i]);
        }

        console.log(
            "current account balance",
            underlyingAcceptedToken.balanceOf(address(this))
        );
        console.log(
            "dev1 superfluid tokens before stream",
            acceptedToken.balanceOf(dev1Receiver)
        );

        uint256 flowAmount = 1000 * 10 ** 18;
        uint256 flowDuration = 30 days;

        underlyingAcceptedToken.approve(address(tagStream), flowAmount);
        tagStream.flowDistributeToRepo(repo1, flowAmount, flowDuration);
        console.log(
            "current account balance after flow",
            underlyingAcceptedToken.balanceOf(address(this))
        );
        ReceiverSuperfluidContract(dev1Receiver).connectToRepo(repo1);
        ReceiverSuperfluidContract(dev1Receiver).setReceiver(dev1Wallet);

        // mock time passing
        vm.warp(block.timestamp + 10 days);
        console.log("tag stream balance", acceptedToken.balanceOf(address(tagStream)));
        console.log(
            "receiver1 superfluid tokens after stream",
            acceptedToken.balanceOf(dev1Receiver)
        );

        vm.startPrank(dev1Wallet);
        ReceiverSuperfluidContract(dev1Receiver).claimRewards();
        console.log(
            "receiver1 superfluid tokens after claim",
            acceptedToken.balanceOf(dev1Receiver)
        );
        console.log("dev1 balance", underlyingAcceptedToken.balanceOf(dev1Wallet));
        vm.stopPrank();

    }
}

