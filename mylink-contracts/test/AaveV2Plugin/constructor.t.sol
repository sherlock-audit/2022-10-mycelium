pragma solidity ^0.8.9;

import "../../src/plugins/AaveV2Plugin.sol";
import "../utils/AaveV2PluginTest.sol";

contract AaveV2Plugin_constructorTest is AaveV2PluginTest {
    function testConstructor() public {
        AaveV2Plugin newPlugin = new AaveV2Plugin(address(this), address(link), address(lendingPool));
        assertEq(address(newPlugin.vault()), address(this), "Vault should be set");
        assertEq(address(newPlugin.LINK()), address(link), "LINK should be set");
        assertEq(address(newPlugin.lendingPool()), address(lendingPool), "Lending pool should be set");
        assertEq(address(newPlugin.aLINK()), address(lendingPool.aLINK()), "aLINK address should be set");
        assertEq(
            link.allowance(address(newPlugin), address(lendingPool)),
            type(uint256).max,
            "Lending pool should be allowed to spend LINK"
        );
    }
}
