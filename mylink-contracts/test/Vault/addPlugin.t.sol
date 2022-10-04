pragma solidity ^0.8.9;

import "../utils/StubPlugin.sol";
import "../utils/VaultTest.sol";

contract Vault_addPluginTest is VaultTest {
    StubPlugin public plugin;

    function _additionalSetup() internal override {
        plugin = new StubPlugin(address(vault), address(link));
        vault.addPlugin(address(plugin), 0);
    }

    function testNonOwner() public {
        vm.expectRevert("Only callable by owner");
        vm.startPrank(bob);
        vault.addPlugin(address(0x11), 0);
    }

    function testAddZeroAddress() public {
        vm.expectRevert("Cannot add zero address");
        vault.addPlugin(address(0), 0);
    }

    function testOverPluginCount() public {
        vm.expectRevert("Index must be less than or equal to plugin count");
        vault.addPlugin(address(0x11), 2);
    }

    function testAddPluginToEnd(address newPlugin) public {
        vm.assume(newPlugin != address(0));
        vault.addPlugin(newPlugin, 1);

        assertEq(vault.plugins(0), address(plugin));
        assertEq(vault.plugins(1), newPlugin);
        assertEq(vault.pluginCount(), 2);
        assertEq(link.allowance(address(vault), newPlugin), type(uint256).max);
    }

    function testAddPluginToStart(address newPlugin) public {
        vm.assume(newPlugin != address(0));
        vault.addPlugin(newPlugin, 0);

        assertEq(vault.plugins(0), newPlugin);
        assertEq(vault.plugins(1), address(plugin));
        assertEq(vault.pluginCount(), 2);
        assertEq(link.allowance(address(vault), newPlugin), type(uint256).max);
    }

    function testAddPluginToMiddle(address middlePlugin, address endPlugin) public {
        vm.assume(middlePlugin != address(0));
        vm.assume(endPlugin != address(0));

        vault.addPlugin(endPlugin, 1);
        vault.addPlugin(middlePlugin, 1);

        assertEq(vault.plugins(0), address(plugin));
        assertEq(vault.plugins(1), middlePlugin);
        assertEq(vault.plugins(2), endPlugin);
        assertEq(vault.pluginCount(), 3);
        assertEq(link.allowance(address(vault), middlePlugin), type(uint256).max);
        assertEq(link.allowance(address(vault), endPlugin), type(uint256).max);
    }
}
