pragma solidity ^0.8.9;

import "../utils/VaultTest.sol";

contract Vault_approveTest is VaultTest {
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function testApproveZeroAddress() public {
        vm.expectRevert("Cannot approve zero address");
        vault.approve(address(0), 1);
    }

    function testApproval(uint256 amount) public {
        vm.startPrank(alice);

        vm.expectEmit(true, true, false, true);
        emit Approval(alice, bob, amount);
        bool res = vault.approve(bob, amount);

        assertTrue(res);
        assertEq(vault.allowance(alice, bob), amount);
    }
}
