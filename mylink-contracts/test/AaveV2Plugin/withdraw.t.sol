pragma solidity ^0.8.9;

import "../utils/AaveV2PluginTest.sol";

contract AaveV2Plugin_withdrawTest is AaveV2PluginTest {
    function testWithdraw() public {
        uint256 amount = 1000;
        vm.assume(amount > 1);

        link.mint(address(this), amount);
        link.approve(address(plugin), amount);
        plugin.deposit(amount);
        plugin.withdraw(amount);

        assertEq(link.balanceOf(address(this)), amount, "LINK should be in the vault");
        assertEq(link.balanceOf(address(plugin)), 0, "LINK should not be in the plugin");
        assertEq(link.balanceOf(address(lendingPool)), 0, "LINK should be withdrawn from the lending pool");
        assertEq(lendingPool.aLINK().balanceOf(address(plugin)), 0, "aLINK should be burned");
        assertEq(plugin.balance(), 0, "Balance should be updated");
    }
}
