pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "../../src/Plugins/AaveV2Plugin.sol";
import "./Token.sol";
import "./StubLendingPool.sol";

abstract contract AaveV2PluginTest is Test {
    Token public link;
    StubLendingPool public lendingPool;
    AaveV2Plugin public plugin;

    function setUp() public {
        link = new Token("LINK", "LINK");
        lendingPool = new StubLendingPool(address(link));
        plugin = new AaveV2Plugin(address(this), address(link), address(lendingPool));
    }
}
