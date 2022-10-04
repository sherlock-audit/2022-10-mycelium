pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "../../src/Vault.sol";
import "../utils/Token.sol";

contract Vault_initializeTest is Test {
    Token public link;
    Vault public vault;

    function setUp() public {
        link = new Token("Chainlink", "LINK");
        vault = new Vault();
    }

    function testInitialize() public {
        vault.initialize(address(link), address(this), 10e34, 1000);
        assertEq(vault.name(), "Mycelium LINK");
        assertEq(vault.symbol(), "myLINK");
        assertEq(vault.decimals(), link.decimals());
        assertEq(vault.LINK(), address(link));
        assertEq(vault.owner(), address(this));
    }
}
