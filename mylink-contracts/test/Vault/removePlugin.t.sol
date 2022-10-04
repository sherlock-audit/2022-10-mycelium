pragma solidity ^0.8.9;

import "../utils/StubPlugin.sol";
import "../utils/VaultTest.sol";

contract Vault_removePluginTest is VaultTest {
    StubPlugin public plugin0;
    StubPlugin public plugin1;
    StubPlugin public plugin2;

    function _additionalSetup() internal override {
        plugin0 = new StubPlugin(address(vault), address(link));
        plugin0.setCapacity(100);
        vault.addPlugin(address(plugin0), 0);

        plugin1 = new StubPlugin(address(vault), address(link));
        plugin1.setCapacity(100);
        vault.addPlugin(address(plugin1), 1);

        plugin2 = new StubPlugin(address(vault), address(link));
        plugin2.setCapacity(100);
        vault.addPlugin(address(plugin2), 2);

        // Users deposit into vault
        link.mint(alice, 50);
        vm.startPrank(alice);
        link.approve(address(vault), 50);
        vault.deposit(50);
        vm.stopPrank();

        link.mint(bob, 100);
        vm.startPrank(bob);
        link.approve(address(vault), 100);
        vault.deposit(100);
        vm.stopPrank();

        link.mint(carol, 150);
        vm.startPrank(carol);
        link.approve(address(vault), 150);
        vault.deposit(150);
        vm.stopPrank();
    }

    function testNonOwner() public {
        vm.expectRevert("Only callable by owner");
        vm.startPrank(bob);
        vault.removePlugin(0);
    }

    function testOutOfBounds(uint256 index) public {
        vm.assume(index >= vault.pluginCount());
        vm.expectRevert("Index out of bounds");
        vault.removePlugin(index);
    }

    function testRemoveEndPlugin() public {
        vault.removePlugin(2);

        assertEq(vault.plugins(0), address(plugin0));
        assertEq(vault.plugins(1), address(plugin1));
        assertEq(vault.plugins(2), address(0));
        assertEq(vault.pluginCount(), 2);

        assertEq(link.balanceOf(address(plugin0)), 100);
        assertEq(link.balanceOf(address(plugin1)), 100);
        assertEq(link.balanceOf(address(plugin2)), 0);
        assertEq(link.balanceOf(address(vault)), 100);
    }

    function testRemoveMiddlePlugin() public {
        vault.removePlugin(1);

        assertEq(vault.plugins(0), address(plugin0));
        assertEq(vault.plugins(1), address(plugin2));
        assertEq(vault.plugins(2), address(0));
        assertEq(vault.pluginCount(), 2);

        assertEq(link.balanceOf(address(plugin0)), 100);
        assertEq(link.balanceOf(address(plugin1)), 0);
        assertEq(link.balanceOf(address(plugin2)), 100);
        assertEq(link.balanceOf(address(vault)), 100);
    }

    function testRemoveFirstPlugin() public {
        vault.removePlugin(0);

        assertEq(vault.plugins(0), address(plugin1));
        assertEq(vault.plugins(1), address(plugin2));
        assertEq(vault.plugins(2), address(0));
        assertEq(vault.pluginCount(), 2);

        assertEq(link.balanceOf(address(plugin0)), 0);
        assertEq(link.balanceOf(address(plugin1)), 100);
        assertEq(link.balanceOf(address(plugin2)), 100);
        assertEq(link.balanceOf(address(vault)), 100);
    }

    function testRemoveAllPlugins() public {
        vault.removePlugin(0);
        vault.removePlugin(0);
        vault.removePlugin(0);

        assertEq(vault.plugins(0), address(0));
        assertEq(vault.plugins(1), address(0));
        assertEq(vault.plugins(2), address(0));
        assertEq(vault.pluginCount(), 0);

        assertEq(link.balanceOf(address(plugin0)), 0);
        assertEq(link.balanceOf(address(plugin1)), 0);
        assertEq(link.balanceOf(address(plugin2)), 0);
        assertEq(link.balanceOf(address(vault)), 300);
    }
}
