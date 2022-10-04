pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "../../src/Vault.sol";
import "../utils/Token.sol";
import "../utils/StubVaultV2.sol";
import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin/proxy/utils/UUPSUpgradeable.sol";

contract Vault_upgradeTest is Test {
    address alice = address(0x1);

    Token public link;
    address public implementation;
    address public proxy;
    Vault public vault;

    function setUp() public {
        vm.label(alice, "Alice");

        link = new Token("Chainlink", "LINK");
        implementation = address(new Vault());
        proxy = address(new ERC1967Proxy(implementation, ""));
        vault = Vault(proxy);
        vault.initialize(address(link), address(this), 10e34, 1000);
    }

    function testProxyRead() public {
        assertEq(vault.LINK(), address(link));
        assertEq(vault.owner(), address(this));
        assertEq(vault.name(), "Mycelium LINK");
        assertEq(vault.symbol(), "myLINK");
        assertEq(vault.decimals(), link.decimals());
    }

    function testProxyWrite(uint256 aliceAmount) public {
        vm.assume(aliceAmount > 0);
        vm.assume(aliceAmount < vault.availableForDeposit());

        vm.startPrank(alice);
        link.mint(address(alice), aliceAmount);
        link.approve(address(proxy), aliceAmount);
        vault.deposit(aliceAmount);
        vm.stopPrank();
        assertEq(vault.balanceOf(alice), aliceAmount);
        assertEq(vault.totalSupply(), aliceAmount);
    }

    function testUpgrade() public {
        StubVaultV2 stub = new StubVaultV2();
        UUPSUpgradeable(proxy).upgradeTo(address(stub));

        assertEq(vault.name(), "StubVaultV2");
    }

    function testNonOwner() public {
        StubVaultV2 stub = new StubVaultV2();
        vm.startPrank(alice);
        vm.expectRevert("Only callable by owner");
        UUPSUpgradeable(proxy).upgradeTo(address(stub));
        vm.stopPrank();
    }
}
