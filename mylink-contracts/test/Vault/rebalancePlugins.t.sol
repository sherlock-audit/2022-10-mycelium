pragma solidity ^0.8.9;

import "../utils/StubPlugin.sol";
import "../utils/VaultTest.sol";

contract Vault_rebalancePluginsTest is VaultTest {
    StubPlugin public plugin0;
    StubPlugin public plugin1;
    StubPlugin public plugin2;

    function _additionalSetup() internal override {
        plugin0 = new StubPlugin(address(vault), address(link));
        vault.addPlugin(address(plugin0), 0);

        plugin1 = new StubPlugin(address(vault), address(link));
        vault.addPlugin(address(plugin1), 1);

        plugin2 = new StubPlugin(address(vault), address(link));
        vault.addPlugin(address(plugin2), 2);
    }

    function testNonOwner() public {
        vm.expectRevert("Only callable by owner");
        vm.startPrank(bob);
        uint256[] memory withdrawalAmounts = new uint256[](3);
        withdrawalAmounts[0] = 0;
        withdrawalAmounts[1] = 0;
        withdrawalAmounts[2] = 0;
        vault.rebalancePlugins(withdrawalAmounts);
    }

    function testIncorrectLength() public {
        vm.expectRevert("Invalid withdrawal values");
        uint256[] memory withdrawalAmounts = new uint256[](2);
        withdrawalAmounts[0] = 0;
        withdrawalAmounts[1] = 0;
        vault.rebalancePlugins(withdrawalAmounts);
    }

    function testRemoveOneAndRebalance(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount <= vault.availableForDeposit());

        plugin0.setCapacity(100);
        plugin1.setCapacity(100);

        // Users deposit into vault
        link.mint(alice, amount);
        vm.startPrank(alice);
        link.approve(address(vault), amount);
        vault.deposit(amount);
        vm.stopPrank();

        uint256 plugin0Balance = link.balanceOf(address(plugin0));

        // Remove plugin0, should return LINK to vault
        vault.removePlugin(0);
        assertEq(link.balanceOf(address(vault)), plugin0Balance);
        assertEq(link.balanceOf(address(plugin0)), 0);

        // Rebalance
        uint256[] memory withdrawalAmounts = new uint256[](2);
        withdrawalAmounts[0] = 0;
        withdrawalAmounts[1] = 0;
        vault.rebalancePlugins(withdrawalAmounts);

        // Check balances
        assertEq(link.balanceOf(address(vault)), 0);
        assertEq(link.balanceOf(address(plugin0)), 0);

        // All LINK should be in plugin1 and plugin2 now
        uint256 plugin1Balance = link.balanceOf(address(plugin1));
        uint256 plugin2Balance = link.balanceOf(address(plugin2));
        assertEq(plugin1Balance + plugin2Balance, amount);
    }

    function testReorderPluginsAndRebalance(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount <= vault.availableForDeposit());

        plugin0.setCapacity(100);
        plugin1.setCapacity(100);

        // Users deposit into vault
        link.mint(alice, amount);
        vm.startPrank(alice);
        link.approve(address(vault), amount);
        vault.deposit(amount);
        vm.stopPrank();

        // Move plugin2 to index 0
        vault.removePlugin(2);
        vault.addPlugin(address(plugin2), 0);
        assertLt(link.balanceOf(address(plugin2)), amount);

        // Plugin2 is first priority now, so it should get all the LINK
        // after rebalancing
        uint256[] memory withdrawalAmounts = new uint256[](3);
        withdrawalAmounts[0] = 0;
        withdrawalAmounts[1] = link.balanceOf(address(plugin0));
        withdrawalAmounts[2] = link.balanceOf(address(plugin1));
        vault.rebalancePlugins(withdrawalAmounts);

        assertEq(link.balanceOf(address(vault)), 0);
        assertEq(link.balanceOf(address(plugin0)), 0);
        assertEq(link.balanceOf(address(plugin1)), 0);
        assertEq(link.balanceOf(address(plugin2)), amount);
    }
}
