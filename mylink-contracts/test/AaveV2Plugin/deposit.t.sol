pragma solidity ^0.8.9;

import "../utils/AaveV2PluginTest.sol";

contract AaveV2Plugin_depositTest is AaveV2PluginTest {
    function testDeposit(uint256 amount) public {
        vm.assume(amount > 0);

        link.mint(address(this), amount);
        link.approve(address(plugin), amount);
        plugin.deposit(amount);

        assertEq(link.balanceOf(address(this)), 0, "LINK should not be in the vault");
        assertEq(link.balanceOf(address(plugin)), 0, "LINK should not be in the plugin");
        assertEq(link.balanceOf(address(lendingPool)), amount, "LINK should be deposited in the lending pool");
        assertEq(lendingPool.aLINK().balanceOf(address(plugin)), amount, "aLINK should be minted");
        assertEq(plugin.balance(), amount, "Balance should be updated");
    }

    function testZeroDeposit() public {
        vm.expectRevert("Amount must be greater than 0");
        plugin.deposit(0);
    }
}
