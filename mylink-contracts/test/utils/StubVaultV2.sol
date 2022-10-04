pragma solidity ^0.8.9;

import "openzeppelin/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin/proxy/utils/Initializable.sol";

contract StubVaultV2 is UUPSUpgradeable, Initializable {
    function name() public pure returns (string memory) {
        return "StubVaultV2";
    }

    function _authorizeUpgrade(address sender) internal override {}
}
